import sys,struct
b=open(sys.argv[1],'rb').read()
b+=b'\x00'*((-len(b))%4)
n=len(b)//4
out=struct.pack('>IIIIII',0x3F3,0,1,0,0,n)+struct.pack('>II',0x3E9,n)+b+struct.pack('>I',0x3F2)
open(sys.argv[2],'wb').write(out)
