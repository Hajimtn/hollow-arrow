import os, sys
import pix
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets')
for d in ('player', 'bosses', 'environment', 'ui', 'vfx', 'audio'):
    os.makedirs(os.path.join(ROOT, d), exist_ok=True)

mods = sys.argv[1:] or ['gen_player', 'gen_tiles', 'gen_decor', 'gen_bosses', 'gen_forms', 'gen_ui', 'gen_pack', 'gen_boss_pack', 'gen_arenas', 'gen_attacks', 'gen_drawn']
for m in mods:
    mod = __import__(m)
    mod.gen(ROOT)
    print('generated', m)
