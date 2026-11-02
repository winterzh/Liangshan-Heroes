"""Windows native retirement for explicitly superseded generated payloads."""
from contextlib import contextmanager
import ctypes
from ctypes import wintypes
import os
from pathlib import Path

if os.name == "nt":
    _attributes = ctypes.WinDLL("kernel32", use_last_error=True).GetFileAttributesW
    _attributes.argtypes = [wintypes.LPCWSTR]
    _attributes.restype = wintypes.DWORD
else:
    _attributes = None

def normal(path):
    path = Path(os.path.abspath(path))
    for item in (path, *path.parents):
        attributes = _attributes("\\\\?\\" + str(item)) if _attributes else getattr(item.lstat(), "st_file_attributes", 0)
        if attributes == 0xFFFFFFFF:
            raise ctypes.WinError(ctypes.get_last_error())
        if attributes & 0x400:
            raise ValueError("Reparse point: " + str(item))
    return path

class FileInfo(ctypes.Structure):
    _fields_ = [("attributes", wintypes.DWORD), ("created", wintypes.FILETIME),
                ("accessed", wintypes.FILETIME), ("written", wintypes.FILETIME),
                ("volume", wintypes.DWORD), ("high", wintypes.DWORD),
                ("low", wintypes.DWORD), ("links", wintypes.DWORD),
                ("index_high", wintypes.DWORD), ("index_low", wintypes.DWORD)]

class StandardInfo(ctypes.Structure):
    _fields_ = [("allocation", ctypes.c_longlong), ("length", ctypes.c_longlong),
                ("links", wintypes.DWORD), ("pending", ctypes.c_ubyte),
                ("directory", ctypes.c_ubyte)]

class NativeFiles:
    def __init__(self):
        self.api = ctypes.WinDLL("kernel32", use_last_error=True)
        self.api.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                        ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
        self.api.CreateFileW.restype = wintypes.HANDLE
        self.api.CloseHandle.argtypes = [wintypes.HANDLE]
        self.api.GetFileInformationByHandle.argtypes = [wintypes.HANDLE, ctypes.POINTER(FileInfo)]
        self.api.GetFileInformationByHandleEx.argtypes = [wintypes.HANDLE, ctypes.c_int,
                                                        ctypes.c_void_p, wintypes.DWORD]
        self.api.SetFileInformationByHandle.argtypes = [wintypes.HANDLE, ctypes.c_int,
                                                        ctypes.c_void_p, wintypes.DWORD]

    @contextmanager
    def handle(self, path, delete=False, pin=False):
        normal(path)
        handle = self.api.CreateFileW("\\\\?\\" + str(path), 0x10080 if delete else (0x80000000 if pin else 0x80),
                                      0 if delete else (1 if pin else 7), None, 3, 0x200000, None)
        if handle == ctypes.c_void_p(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            yield handle
        finally:
            self.api.CloseHandle(handle)

    def metadata(self, handle):
        info, standard = FileInfo(), StandardInfo()
        if (not self.api.GetFileInformationByHandle(handle, ctypes.byref(info)) or
                not self.api.GetFileInformationByHandleEx(handle, 1, ctypes.byref(standard), ctypes.sizeof(standard))):
            raise ctypes.WinError(ctypes.get_last_error())
        identity = (info.volume, info.index_high, info.index_low, standard.length,
                    info.created.dwHighDateTime, info.created.dwLowDateTime,
                    info.written.dwHighDateTime, info.written.dwLowDateTime)
        if info.attributes & 0x411 or standard.directory or standard.pending:
            raise ValueError("Readonly, reparse, directory or delete-pending file")
        return identity, standard

    def snapshot(self, path):
        with self.handle(path) as handle:
            identity, _ = self.metadata(handle)
            return identity

    def delete(self, path, expected):
        # The same exclusive handle validates identity and deletes only this name.
        # Other hardlink names/content are preserved; count allocation only for last link.
        with self.handle(path, delete=True) as handle:
            identity, standard = self.metadata(handle)
            if identity != expected:
                raise ValueError("File changed since retirement inventory")
            normal(path)
            disposition = wintypes.BOOL(True)
            if not self.api.SetFileInformationByHandle(handle, 4, ctypes.byref(disposition), ctypes.sizeof(disposition)):
                raise ctypes.WinError(ctypes.get_last_error())
            return standard.length, standard.allocation if standard.links == 1 else 0

def freeze_tree(root, native):
    root = normal(root)
    files, directories = [], [root]
    def fail(error):
        raise error
    for parent, children, names in os.walk(root, followlinks=False, onerror=fail):
        for name in children:
            directories.append(normal(Path(parent) / name))
        for name in names:
            path = normal(Path(parent) / name)
            files.append((path, native.snapshot(path)))
    return files, sorted(directories, key=lambda p: len(p.parts), reverse=True)
