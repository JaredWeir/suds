#!/bin/bash
B=weirortho-cinema-suds-films-170157272794
mkdir -p /tmp/work && cd /tmp/work
ls ffmpeg-*-static/ffmpeg >/dev/null 2>&1 || { echo "[*]ffmpeg"; curl -sL https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz -o f.tar.xz && tar xf f.tar.xz; }
FF=$(ls ffmpeg-*-static/ffmpeg|head -1); FP=$(ls ffmpeg-*-static/ffprobe|head -1)
resolve(){ python3 - "$1" "$2" <<'PY'
import json,urllib.parse,subprocess,sys
def get(u): return subprocess.run(['curl','-s','--max-time','15',u],capture_output=True,text=True).stdout
def best(ident):
  try: d=json.loads(get('https://archive.org/metadata/'+ident))
  except: return None
  b=None
  for f in d.get('files',[]):
    n=f.get('name','')
    if n.lower().endswith('.mp4'):
      s=int(f.get('size',0) or 0)
      if s>250_000_000 and (b is None or s<b[1]): b=(n,s)
  return ('https://archive.org/download/'+ident+'/'+urllib.parse.quote(b[0])) if b else None
u=best(sys.argv[1])
if not u and len(sys.argv)>2:
  t=sys.argv[2]
  su='https://archive.org/advancedsearch.php?q='+urllib.parse.quote('title:("%s") AND mediatype:movies'%t)+'&fl[]=identifier&rows=6&output=json'
  try: ids=[d['identifier'] for d in json.loads(get(su))['response']['docs']]
  except: ids=[]
  for i in ids:
    il=i.lower()
    if 'mst3k' in il or 'trailer' in il: continue
    u=best(i)
    if u: break
print(u or '')
PY
}
proc(){ slug=$1; ident=$2; title=$3
  aws s3 ls "s3://$B/films/$slug.mp4" >/dev/null 2>&1 && { echo "SKIP $slug"; return 0; }
  url=$(resolve "$ident" "$title"); [ -z "$url" ] && { echo "NOURL $slug"; return 1; }
  echo "=== $slug $(date +%T) ==="
  curl -sL --max-time 1500 "$url" -o in.mp4 || { echo "DLFAIL $slug"; return 1; }
  cod=$("$FP" -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 in.mp4 2>/dev/null); echo "  codec=$cod size=$(du -m in.mp4|cut -f1)MB"
  if [ "$cod" = "h264" ]; then
    "$FF" -y -loglevel error -i in.mp4 -c copy -movflags +faststart out.mp4 2>/dev/null || "$FF" -y -loglevel error -i in.mp4 -c:v libx264 -preset ultrafast -crf 22 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart out.mp4
  else
    "$FF" -y -loglevel error -i in.mp4 -c:v libx264 -preset ultrafast -crf 22 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart out.mp4
  fi
  [ -f out.mp4 ] || { echo "ENCFAIL $slug"; rm -f in.mp4; return 1; }
  aws s3 cp out.mp4 "s3://$B/films/$slug.mp4" --content-type video/mp4 --only-show-errors && echo "  UP $slug $(du -m out.mp4|cut -f1)MB $(date +%T)"
  rm -f in.mp4 out.mp4
}
proc the-lost-world TheLostWorldWallaceBeerysilent "The Lost World 1925"
proc house-on-haunted-hill house-on-haunted-hill-1959_202511 "House on Haunted Hill 1959"
proc white-zombie dom-8879-1-white-zombie-hd "White Zombie 1932"
proc the-bat the-bat-1959 "The Bat 1959"
proc one-million-bc one.million.b.c.1940 "One Million B.C. 1940"
proc first-spaceship-on-venus AFNT31FirstSpaceshipOnVenusV2 "First Spaceship on Venus"
proc attack-of-the-50-foot-woman attack-of-the-50-foot-woman-1958_202510 "Attack of the 50 Foot Woman"
proc the-wasp-woman TheWaspWoman1959_898 "The Wasp Woman"
proc bride-of-the-monster bride-of-the-monster-1955 "Bride of the Monster"
proc plan-9 20191012_20191012_1912 "Plan 9 from Outer Space"
proc a-christmas-carol a-christmas-carol-scrooge-1951 "A Christmas Carol 1951"
proc the-snow-queen the-snow-queen-1957-1959-english-dub "The Snow Queen 1957"
proc march-of-the-wooden-soldiers BabesInToylandBW "March of the Wooden Soldiers"
proc the-holly-and-the-ivy the-holly-and-the-ivy-1952 "The Holly and the Ivy 1952"
proc beyond-tomorrow beyond-tomorrow-1.1 "Beyond Tomorrow 1940"
proc the-great-rupert the-great-rupert-1950 "The Great Rupert 1950"
echo "=== SEASONAL BATCH COMPLETE $(date +%T) ==="
aws s3 ls "s3://$B/films/" | wc -l
