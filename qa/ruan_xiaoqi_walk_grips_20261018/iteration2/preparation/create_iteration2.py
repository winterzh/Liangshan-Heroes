import ast,pathlib
E=pathlib.Path(__file__).parent;N=E/'iteration2';N.mkdir(exist_ok=False)
s=(E/'prepare_comparison.py').read_text('utf-8')
a=s.index('specs=');b=s.index('\ntargets=',a)
s=s[:a]+'''specs=[('push_contact_a','contact_a',{'se':[[414,378],[534,326]],'sw':[[762,332],[886,382]]}),
('push_passing_a','passing_a_padded',{'se':[[397,380],[516,327]],'sw':[[751,326],[870,384]],'ne':[[512,963]],'nw':[[743,965]]}),
('push_contact_b','contact_b',{'ne':[[537,933]],'nw':[[750,941]]}),
('push_contact_b','contact_b_se_primary',{'se':[[354,350],[555,253]]}),
('push_contact_b','contact_b_sw_close',{'sw':[[326,583],[621,677]]}),
('push_passing_b','passing_b_padded',{'se':[[402,392],[519,332]],'sw':[[753,329],[887,398]],'ne':[[523,934]],'nw':[[768,945]]})]
'''+s[b:]
s=s.replace('for state,(source_key,grips) in specs.items():','for state,source_key,grips in specs:')
s=s.replace('pivot=[roots[d],y+int(yy.max())+1]','pivot=[old["pivot_native"][0] if source_key=="contact_b_sw_close" else roots[d],y+int(yy.max())+1]')
s=s.replace("assert len(m['sources'])==7","assert len(m['sources'])==9")
ast.parse(s);(N/'prepare_comparison.py').write_bytes(s.encode())
s=(E/'integrate_after_native.py').read_text('utf-8').replace('assert len(new_files)==8','assert len(new_files)==10').replace("'future_native_references_expected':174","'future_native_references_expected':176").replace("'new_runtime_files':8","'new_runtime_files':len(new_files)")
ast.parse(s);(N/'integrate_after_native.py').write_bytes(s.encode())
print(str(N))
