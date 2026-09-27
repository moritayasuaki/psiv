"""Structural verification of emitted Rust bitcode with rustc's matching LLVM C API."""
import ctypes as C, hashlib, json, os, pathlib, subprocess, sys
if len(sys.argv) != 2:
 raise SystemExit('usage: verify_rust_llvm.py path/to/module.bc')
root=pathlib.Path(__file__).resolve().parents[1]
sysroot=pathlib.Path(subprocess.check_output(['rustc','--print','sysroot'],text=True).strip())
library=pathlib.Path(os.environ.get('RUST_LLVM_LIBRARY',sysroot/'lib/libLLVM.dylib'))
llvm=C.CDLL(str(library));P=C.c_void_p;PP=C.POINTER(P);I=C.c_int
for name,args,result in [
 ('LLVMContextCreate',[],P),('LLVMCreateMemoryBufferWithContentsOfFile',[C.c_char_p,PP,PP],I),
 ('LLVMParseBitcodeInContext2',[P,P,PP],I),('LLVMVerifyModule',[P,I,PP],I),
 ('LLVMDisposeMessage',[P],None),('LLVMDisposeModule',[P],None),
 ('LLVMDisposeMemoryBuffer',[P],None),('LLVMContextDispose',[P],None)]:
 f=getattr(llvm,name);f.argtypes=args;f.restype=result
path=pathlib.Path(sys.argv[1]).resolve();ctx=llvm.LLVMContextCreate();buf=P();module=P();message=P()
try:
 assert llvm.LLVMCreateMemoryBufferWithContentsOfFile(os.fsencode(path),C.byref(buf),C.byref(message))==0
 assert llvm.LLVMParseBitcodeInContext2(ctx,buf,C.byref(module))==0
 status=llvm.LLVMVerifyModule(module,2,C.byref(message))
 diagnostic=C.string_at(message).decode() if message.value else ''
 assert status==0,diagnostic
 report={'status':'PASS','check':'LLVMVerifyModule with LLVMReturnStatusAction','library':str(library),'module':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'scope':'Core-module structural validity only; no functional, dependency-composition or timing proof'}
 (root/'.local/reports').mkdir(parents=True,exist_ok=True)
 (root/'.local/reports/rust-llvm-verify.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
finally:
 if message.value:llvm.LLVMDisposeMessage(message)
 if module.value:llvm.LLVMDisposeModule(module)
 if buf.value:llvm.LLVMDisposeMemoryBuffer(buf)
 llvm.LLVMContextDispose(ctx)
