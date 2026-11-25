"""Reproducible explanation animation. Requires Pillow and imageio-ffmpeg."""
from pathlib import Path
import json, math, subprocess, wave
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
W, H, FPS = 1280, 720, 24
BG = '#f3f6fb'
INK = '#172843'
MUTED = '#60738e'
BLUE = '#2563eb'
GREEN = '#059b82'
FONT = 'C:/Windows/Fonts/malgun.ttf'
BOLD = 'C:/Windows/Fonts/malgunbd.ttf'
fonts = {}
def font(size, bold=False):
    key = (size, bold)
    if key not in fonts: fonts[key] = ImageFont.truetype(BOLD if bold else FONT, size)
    return fonts[key]

def txt(d, xy, text, size=22, color=INK, bold=False, anchor=None):
    d.text(xy, text, font=font(size, bold), fill=color, anchor=anchor, spacing=14)

def rr(d, box, fill, r=20, outline=None, width=1):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)

def wrapped(d, xy, text, width, size=24, color=MUTED, bold=False, gap=10):
    line = ''; y = xy[1]
    for char in text:
        if char == '\n' or d.textlength(line + char, font=font(size, bold)) > width:
            txt(d, (xy[0], y), line, size, color, bold)
            y += size + gap; line = '' if char == '\n' else char
        else: line += char
    if line: txt(d, (xy[0], y), line, size, color, bold)
    return y + size

def ease(v):
    v = max(0, min(1, v)); return v*v*(3-2*v)

def pin(d, x, y, color=BLUE):
    d.ellipse((x-14,y-23,x+14,y+5), fill=color)
    d.polygon([(x-10,y-1),(x+10,y-1),(x,y+18)],fill=color)
    d.ellipse((x-5,y-15,x+5,y-5),fill='white')

def home(d, x, y):
    d.polygon([(x-24,y),(x,y-23),(x+24,y)],fill=INK)
    rr(d,(x-18,y,x+18,y+29),'white',4)
    d.rectangle((x-5,y+10,x+5,y+29),fill=BLUE)

def map_card(im, box, progress, crossing=False):
    d=ImageDraw.Draw(im); x1,y1,x2,y2=box
    rr(d,box,'#e5eee9',26)
    for bx,by,bw,bh in [(20,32,66,50),(110,20,80,60),(256,35,66,78),(22,230,78,60),(270,250,65,67),(115,315,80,40)]:
        rr(d,(x1+bx,y1+by,x1+bx+bw,y1+by+bh),'#cedbd5',7)
    d.line([(x1+2,y1+170),(x2-2,y1+170)],fill='white',width=28)
    d.line([(x1+220,y1+4),(x1+220,y2-4)],fill='white',width=24)
    cx,cy=x1+190,y1+185; radius=114
    layer=Image.new('RGBA',im.size); ld=ImageDraw.Draw(layer)
    ld.ellipse((cx-radius,cy-radius,cx+radius,cy+radius),fill=(37,99,235,30),outline=(37,99,235,200),width=3)
    im.paste(layer,(0,0),layer); d=ImageDraw.Draw(im)
    home(d,cx,cy-18)
    txt(d,(cx,cy+31),'설정한 집',17,INK,True,'mm')
    rr(d,(x1+16,y1+16,x1+146,y1+47),'white',12)
    txt(d,(x1+81,y1+31),'반경 200m · 예시',14,MUTED,False,'mm')
    px=x1+23+int(105*progress); py=cy+55
    for k in range(0,110,17):
        d.line((x1+23+k,py,x1+31+k,py),fill='#95a9ba',width=3)
    pulse=5+int(4*(.5+.5*math.sin(progress*16)))
    d.ellipse((px-17-pulse,py-17-pulse,px+17+pulse,py+17+pulse),outline=BLUE,width=2)
    d.ellipse((px-12,py-12,px+12,py+12),fill=BLUE,outline='white',width=3)
    if crossing and progress>.62:
        rr(d,(x1+82,y2-59,x2-25,y2-16),GREEN,15)
        txt(d,((x1+82+x2-25)//2,y2-38),'반경 안으로 진입 감지',18,'white',True,'mm')
    txt(d,(x1+16,y2-91),'이동 경로·거리 표현은 예시입니다',13,MUTED)

def phone(im, mode, p):
    d=ImageDraw.Draw(im)
    rr(d,(838,116,1200,632),'#dce3ef',37)
    rr(d,(830,108,1192,624),INK,36)
    rr(d,(840,118,1182,614),'#f8fafc',28)
    rr(d,(943,124,1079,144),INK,12)
    txt(d,(859,150),'9:41',13,INK,True)
    txt(d,(1162,150),'● ▰',12,INK,False,'ra')
    if mode=='setup':
        txt(d,(858,182),'집 반경 · 실내 지도 안내',21,INK,True)
        preview=Image.new('RGB',(412,426),BG)
        map_card(preview,(0,0,412,426),.85)
        im.paste(preview.resize((308,198),Image.Resampling.LANCZOS),(857,215))
        d=ImageDraw.Draw(im)
        txt(d,(860,430),'반경 200m',20,INK,True)
        d.line((863,474,1150,474),fill='#c5d4ef',width=5)
        d.ellipse((972,465,990,483),fill=BLUE)
        txt(d,(859,505),'집 반경 감시',20,INK,True)
        rr(d,(1090,505,1153,536),GREEN,17)
        d.ellipse((1125,509,1149,533),fill='white')
        txt(d,(860,550),'위치·알림 권한 허용 후 감시',16,MUTED)
    elif mode in ('background','service','notify'):
        rr(d,(852,180,1170,586),'#e8effa',20)
        txt(d,(1011,207),'11월 23일 월요일',17,MUTED,False,'mm')
        txt(d,(1011,259),'09:41',58,INK,True,'mm')
        for i,(label,col) in enumerate([('전화','#63bfa8'),('메시지','#6d9edb'),('사진','#e9b66c'),('설정','#91a0b7')]):
            x=876+i*76; rr(d,(x,510,x+47,557),col,12)
            txt(d,(x+23,572),label,12,MUTED,False,'mm')
        if mode=='background':
            rr(d,(874,333,1148,419),'white',18)
            txt(d,(1011,359),'APT EV',23,INK,True,'mm')
            txt(d,(1011,391),'앱은 백그라운드 상태',17,MUTED,False,'mm')
        else:
            rr(d,(852,310,1170,430),'white',20, '#d4deed')
            txt(d,(868,325),'APT EV · 실내 위치 안내',14,BLUE,True)
            if mode=='service':
                txt(d,(868,358),'주변 위치를',22,INK,True)
                txt(d,(868,386),'확인하고 있습니다',22,INK,True)
                txt(d,(869,452),'실내 위치 안내를 위한',17,MUTED)
                txt(d,(869,480),'최대 20분 관찰',17,MUTED)
            else:
                txt(d,(868,358),'실내 위치 안내',24,INK,True)
                txt(d,(868,397),'실내 지도를 열어 위치를 확인하세요',15,MUTED)
                if p>.48:
                    pulse=20+int(14*(.5+.5*math.sin(p*25)))
                    d.ellipse((1062-pulse,392-pulse,1062+pulse,392+pulse),outline=BLUE,width=3)
                    d.ellipse((1055,385,1069,399),fill=BLUE)
                    txt(d,(1011,460),'알림 터치 → 앱 열기',19,BLUE,True,'mm')
    elif mode=='indoor':
        txt(d,(859,185),'내 위치 · 실내 지도',23,INK,True)
        rr(d,(856,225,1167,267),'#e7eefc',12)
        txt(d,(886,245),'B1',18,BLUE,True,'mm'); txt(d,(960,245),'B2',18,MUTED,False,'mm')
        indoor=Image.open(REPO/'assets/images/B1-simplified.png').convert('RGB')
        indoor.thumbnail((302,215))
        im.paste(indoor,(860+(302-indoor.width)//2,290+(215-indoor.height)//2))
        d=ImageDraw.Draw(im)
        d.ellipse((992,385,1014,407),fill=BLUE,outline='white',width=3)
        txt(d,(1011,518),'위치 표시는 예시입니다',16,MUTED,False,'mm')
        rr(d,(859,550,1164,589),'#e6f4ee',12)
        txt(d,(1011,569),'집 반경 감시 · 언제든 끄기 가능',16,GREEN,True,'mm')
    d.line((958,601,1063,601),fill='#8091aa',width=4)

SCENES=json.loads((ROOT/'scenes.json').read_text(encoding='utf-8'))
def render(idx,p):
    im=Image.new('RGB',(W,H),BG); d=ImageDraw.Draw(im)
    d.rectangle((0,0,W,7),fill=BLUE)
    txt(d,(58,34),'APT EV  /  위치 기반 실내 지도 안내',20,INK,True)
    rr(d,(820,30,1221,66),'#e4ebf5',16)
    txt(d,(1020,48),'기능 설명 애니메이션 · 실제 앱 녹화 아님',16,MUTED,False,'mm')
    s=SCENES[idx]
    rr(d,(60,130,340,169),'#e3ecff',15)
    txt(d,(79,138),f'0{idx+1}   {s["label"]}',18,BLUE,True)
    txt(d,(60,200),s['title'],43,INK,True)
    notes=[
        ['집 위치·반경 저장','사용 안내 동의 및 권한 허용','사용자가 직접 감시 켜기'],
        ['설정한 구역을 향해 이동','휴대폰에서 앱을 사용하지 않는 상황','위치·권한·OS 조건에 따라 감지'],
        ['구역 경계 통과 → 진입 이벤트','진입 근거를 바탕으로 위치 관찰','시작 제한 시 알림으로 재시도'],
        ['진행 중 알림으로 작업 상태 표시','관찰 시간은 최대 20분','앱 화면이 뒤에 있어도 상태 확인'],
        ['반경 진입 + 지속된 위치 신호 저하','실내 위치 안내 알림 도착','사용자가 눌러 실내 지도 열기'],
        ['공유된 비콘 자료로 실내 위치 추정','지하 지도에서 위치 확인','설정에서 감시 중지·집 설정 삭제']
    ][idx]
    for k,line in enumerate(notes):
        y=366+k*49
        d.ellipse((65,y+9,73,y+17),fill=BLUE)
        txt(d,(91,y),line,22,MUTED)
    if idx in (1,2):
        map_card(im,(806,126,1218,552),ease(p) if idx==2 else .18*ease(p),idx==2)
        d=ImageDraw.Draw(im)
        rr(d,(827,568,1197,611),'white',15)
        txt(d,(1012,589),'앱은 백그라운드 · 반경 감시 켜짐',17,BLUE,True,'mm')
    else: phone(im,['setup','','','service','notify','indoor'][idx],p)
    d=ImageDraw.Draw(im)
    # Caption area keeps Korean text readable against all scene illustrations.
    rr(d,(43,638,1237,700),INK,17)
    txt(d,(640,667),s['caption'],23,'white',True,'mm')
    for k in range(6):
        x=60+k*104
        rr(d,(x,566,x+88,572),BLUE if k<=idx else '#d6e0ef',3)
        txt(d,(x,584),['설정','이동','진입','관찰','알림','앱 열기'][k],15,BLUE if k==idx else MUTED,k==idx)
    return im

def main():
    ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
    durations=[]; chunks=[]; params=None
    for s in SCENES:
        with wave.open(str(ROOT/(s['id']+'.wav')),'rb') as f:
            if params is None: params=f.getparams()
            assert f.getnchannels()==params.nchannels and f.getframerate()==params.framerate and f.getsampwidth()==params.sampwidth
            pcm=f.readframes(f.getnframes())
        rawlen=len(pcm)/(params.framerate*params.nchannels*params.sampwidth)
        duration=math.ceil((rawlen+1.2)*FPS)/FPS
        durations.append(duration)
        lead=round(.35*params.framerate)
        target=round(duration*params.framerate)
        tail=target-lead-len(pcm)//(params.nchannels*params.sampwidth)
        chunks.append(b'\0'*(lead*params.nchannels*params.sampwidth)+pcm+b'\0'*(tail*params.nchannels*params.sampwidth))
    audio=ROOT/'narration.wav'
    with wave.open(str(audio),'wb') as f:
        f.setparams(params); f.writeframes(b''.join(chunks))
    def stamp(t):
        ms=round(t*1000); return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
    elapsed=0; subs=[]
    for idx,(s,dur) in enumerate(zip(SCENES,durations)):
        subs.append(f'{idx+1}\n{stamp(elapsed)} --> {stamp(elapsed+dur)}\n{s["caption"]}\n')
        elapsed+=dur
    (ROOT/'geofence-explainer.ko.srt').write_text('\n'.join(subs),encoding='utf-8-sig')
    output=ROOT/'APT-EV-geofence-explainer-ko.mp4'
    command=[ffmpeg,'-y','-f','rawvideo','-vcodec','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-i',str(audio),'-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart','-shortest',str(output)]
    log=open(ROOT/'encode.log','w',encoding='utf-8')
    proc=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=log,stderr=log)
    sheet=Image.new('RGB',(960,810),'white')
    previous=None
    try:
        for idx,dur in enumerate(durations):
            n=round(dur*FPS)
            sample=render(idx,.76)
            sample.resize((480,270)).save(ROOT/f'scene-{idx+1:02}.jpg',quality=92)
            sheet.paste(sample.resize((480,270)),((idx%2)*480,(idx//2)*270))
            for frame in range(n):
                im=sample if idx in (0,3,5) else render(idx,frame/max(1,n-1))
                if previous is not None and frame<7: im=Image.blend(previous,im,(frame+1)/7)
                proc.stdin.write(im.tobytes())
            previous=im
            print(f'Scene {idx+1}/6 encoded ({dur:.2f}s)',flush=True)
        proc.stdin.close(); code=proc.wait()
        if code: raise RuntimeError(f'FFmpeg failed: {code}')
    finally: log.close()
    sheet.save(ROOT/'contact-sheet.jpg',quality=94)
    render(2,.85).save(ROOT/'poster.jpg',quality=95)
    (ROOT/'video-metadata.json').write_text(json.dumps({'duration_seconds':elapsed,'scene_durations':durations,'width':W,'height':H,'fps':FPS,'type':'explanation animation, not device footage','narration':'Microsoft Heami Desktop ko-KR','output':output.name},ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'Finished: {output.name}, duration {elapsed:.2f}s',flush=True)

if __name__=='__main__': main()
