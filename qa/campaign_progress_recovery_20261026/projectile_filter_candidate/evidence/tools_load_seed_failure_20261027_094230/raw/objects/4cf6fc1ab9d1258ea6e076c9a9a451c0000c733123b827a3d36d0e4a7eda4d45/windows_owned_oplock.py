"""Exclusive Windows file oplock for one verified owned fixture, without process hooks."""
import ctypes as ct
from ctypes import wintypes as wt
from pathlib import Path

class Overlapped(ct.Structure):
    _fields_ = [('Internal',ct.c_size_t),('InternalHigh',ct.c_size_t),('Offset',wt.DWORD),
               ('OffsetHigh',wt.DWORD),('hEvent',wt.HANDLE)]

class OwnedOplock:
    FSCTL_REQUEST_OPLOCK_LEVEL_1 = 0x00090000
    ERROR_IO_PENDING = 997
    WAIT_OBJECT_0 = 0
    WAIT_TIMEOUT = 258
    INVALID_HANDLE = ct.c_void_p(-1).value

    def __init__(self, path, owned_root):
        path=Path(path); owned_root=Path(owned_root)
        if not path.is_file() or not path.resolve().is_relative_to(owned_root.resolve()):
            raise RuntimeError('Oplock fixture is not an existing owned file')
        for item in [path,*path.parents]:
            if item.exists() and (item.is_symlink() or getattr(item.lstat(),'st_file_attributes',0)&0x400):
                raise RuntimeError('Oplock reparse path refused')
        self.path=path
        self.api=ct.WinDLL('kernel32',use_last_error=True)
        definitions={
            'CreateFileW':([wt.LPCWSTR,wt.DWORD,wt.DWORD,ct.c_void_p,wt.DWORD,wt.DWORD,wt.HANDLE],wt.HANDLE),
            'CreateEventW':([ct.c_void_p,wt.BOOL,wt.BOOL,wt.LPCWSTR],wt.HANDLE),
            'DeviceIoControl':([wt.HANDLE,wt.DWORD,ct.c_void_p,wt.DWORD,ct.c_void_p,wt.DWORD,ct.POINTER(wt.DWORD),ct.POINTER(Overlapped)],wt.BOOL),
            'GetOverlappedResult':([wt.HANDLE,ct.POINTER(Overlapped),ct.POINTER(wt.DWORD),wt.BOOL],wt.BOOL),
            'WaitForSingleObject':([wt.HANDLE,wt.DWORD],wt.DWORD),
            'GetFileSizeEx':([wt.HANDLE,ct.POINTER(ct.c_int64)],wt.BOOL),
            'WriteFile':([wt.HANDLE,ct.c_void_p,wt.DWORD,ct.POINTER(wt.DWORD),ct.POINTER(Overlapped)],wt.BOOL),
            'FlushFileBuffers':([wt.HANDLE],wt.BOOL),
            'CancelIoEx':([wt.HANDLE,ct.POINTER(Overlapped)],wt.BOOL),
            'CloseHandle':([wt.HANDLE],wt.BOOL),
        }
        for name,(arguments,result) in definitions.items():
            function=getattr(self.api,name); function.argtypes=arguments; function.restype=result
        self.handle=self.event=None
        self.overlapped=Overlapped()
        self.break_observed=False
        self.pending=False
        try:
            # OPEN_EXISTING, READ|WRITE, share READ|WRITE|DELETE, OVERLAPPED.
            self.handle=self.api.CreateFileW(str(path),0xC0000000,7,None,3,0x40000000,None)
            if self.handle==self.INVALID_HANDLE: self.handle=None; self._error()
            self.event=self.api.CreateEventW(None,True,False,None)
            if not self.event: self._error()
            self.overlapped.hEvent=self.event
            returned=wt.DWORD()
            ct.set_last_error(0)
            immediate=self.api.DeviceIoControl(self.handle,self.FSCTL_REQUEST_OPLOCK_LEVEL_1,None,0,None,0,
                                               ct.byref(returned),ct.byref(self.overlapped))
            if immediate or ct.get_last_error()!=self.ERROR_IO_PENDING:
                raise RuntimeError('Exclusive oplock must be pending, not pre-broken or unsupported: '+str(ct.get_last_error()))
            self.pending=True
        except BaseException:
            self.close()
            raise

    def _error(self):
        raise ct.WinError(ct.get_last_error())

    def poll_break(self):
        status=self.api.WaitForSingleObject(self.event,0)
        if status==self.WAIT_TIMEOUT: return False
        if status!=self.WAIT_OBJECT_0: self._error()
        returned=wt.DWORD()
        if not self.api.GetOverlappedResult(self.handle,ct.byref(self.overlapped),ct.byref(returned),False): self._error()
        self.pending=False
        self.break_observed=True
        return True

    def append_before_release(self, data):
        if not self.break_observed or type(data) is not bytes or not data:
            raise RuntimeError('Observed real opener break and bounded byte comment required')
        if len(data)>4096: raise RuntimeError('Oplock fixture mutation size limit')
        length=ct.c_int64()
        if not self.api.GetFileSizeEx(self.handle,ct.byref(length)): self._error()
        event=self.api.CreateEventW(None,True,False,None)
        if not event: self._error()
        try:
            io=Overlapped(); io.Offset=length.value&0xFFFFFFFF; io.OffsetHigh=length.value>>32; io.hEvent=event
            buffer=ct.create_string_buffer(data); written=wt.DWORD()
            ct.set_last_error(0)
            done=self.api.WriteFile(self.handle,buffer,len(data),ct.byref(written),ct.byref(io))
            if not done:
                if ct.get_last_error()!=self.ERROR_IO_PENDING: self._error()
                if self.api.WaitForSingleObject(event,10000)!=self.WAIT_OBJECT_0: raise RuntimeError('Owned append native timeout')
                if not self.api.GetOverlappedResult(self.handle,ct.byref(io),ct.byref(written),False): self._error()
            if written.value!=len(data): raise RuntimeError('Partial owned real append')
            if not self.api.FlushFileBuffers(self.handle): self._error()
        finally:
            self.api.CloseHandle(event)
        self.close() # Closing the exclusive handle acknowledges the break; blocked opener can continue.

    def close(self):
        if self.handle:
            if self.pending:
                # Keep OVERLAPPED/event storage alive until the kernel completes cancellation.
                self.api.CancelIoEx(self.handle,ct.byref(self.overlapped))
                if self.api.WaitForSingleObject(self.event,10000)!=self.WAIT_OBJECT_0:
                    raise RuntimeError('Owned pending oplock cancellation did not complete')
                self.pending=False
            self.api.CloseHandle(self.handle); self.handle=None
        if self.event:
            self.api.CloseHandle(self.event); self.event=None
