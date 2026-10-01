import sys
from PIL import Image
sp=open('/tmp/claude-501/sp.txt').read().strip()
src=sys.argv[1]; k=int(sys.argv[2]) if len(sys.argv)>2 else 4
im=Image.open(src).convert('RGBA'); im=im.resize((im.width*k,im.height*k),Image.NEAREST)
bg=Image.new('RGBA',im.size,(74,84,74,255)); bg.alpha_composite(im); bg.save(sp+'/prev.png'); print(sp+'/prev.png')
