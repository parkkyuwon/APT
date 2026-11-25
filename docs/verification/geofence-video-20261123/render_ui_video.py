"""Silent portrait UI walkthrough. Clearly labeled as a UI reproduction."""
import json, subprocess
from pathlib import Path
from PIL import Image, ImageDraw
import render_video as base

ROOT=Path(__file__).resolve().parent
W,H,FPS=720,1280,24
HEADINGS=['집 반경 설정 후 감시 켜기','앱을 사용하지 않는 동안 이동','설정한 반경 안으로 진입','위치 확인 알림 표시','안내 알림 터치','앱의 실내 지도 열기']
CAPTIONS=['위치·알림 권한 허용 후 사용','집 반경 감시가 켜진 상태','진입 감지 → 주변 위치 관찰 시작','실내 안내를 위한 관찰 · 최대 20분','진입 후 위치 신호 저하가 지속되면 안내','알림을 누르면 실내 지도 화면으로 이동']

def render(idx,p):
    im=Image.new('RGB',(W,H),base.BG); d=ImageDraw.Draw(im)
    d.rectangle((0,0,W,7),fill=base.BLUE)
    base.txt(d,(40,36),'APT EV',22,base.INK,True)
    base.txt(d,(680,40),'설명용 UI 재현 · 실제 녹화 아님',18,base.MUTED,False,'ra')
    base.txt(d,(40,103),f'0{idx+1} / 06',21,base.BLUE,True)
    base.txt(d,(40,150),HEADINGS[idx],32,base.INK,True)
    if idx in (1,2):
        mapim=Image.new('RGB',(412,426),base.BG)
        progress=.18*base.ease(p) if idx==1 else .18+.82*base.ease(p)
        base.map_card(mapim,(0,0,412,426),progress,idx==2)
        im.paste(mapim.resize((620,641),Image.Resampling.LANCZOS),(50,291))
        d=ImageDraw.Draw(im)
        base.rr(d,(70,963,650,1024),'white',20)
        base.txt(d,(360,993),'앱은 백그라운드 · 집 반경 감시 켜짐',23,base.BLUE,True,'mm')
    else:
        canvas=Image.new('RGB',(1280,720),base.BG)
        base.phone(canvas,['setup','','','service','notify','indoor'][idx],p)
        if idx==0:
            cd=ImageDraw.Draw(canvas)
            enabled=p>.52
            base.rr(cd,(1090,505,1153,536),base.GREEN if enabled else '#b7c3d1',17)
            x=1125 if enabled else 1094
            cd.ellipse((x,509,x+24,533),fill='white')
        phone=canvas.crop((824,102,1206,630)).resize((592,818),Image.Resampling.LANCZOS)
        im.paste(phone,(64,229))
    d=ImageDraw.Draw(im)
    base.rr(d,(30,1080,690,1160),base.INK,20)
    base.txt(d,(360,1118),CAPTIONS[idx],23,'white',True,'mm')
    for k in range(6):
        x=40+k*109
        base.rr(d,(x,1204,x+91,1210),base.BLUE if k<=idx else '#d7e1ee',3)
        base.txt(d,(x+45,1238),['설정','이동','진입','관찰','알림','앱 열기'][k],17,base.BLUE if k==idx else base.MUTED,k==idx,'mm')
    return im

def main():
    path=ROOT/'APT-EV-geofence-UI-silent.mp4'
    ff=base.imageio_ffmpeg.get_ffmpeg_exe()
    cmd=[ff,'-y','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-an','-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(path)]
    sheet=Image.new('RGB',(720,1280),'white')
    with open(ROOT/'encode-ui.log','w',encoding='utf-8') as log:
        proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=log,stderr=log)
        prev=None
        for idx in range(6):
            for f in range(5*FPS):
                im=render(idx,f/(5*FPS-1))
                if prev is not None and f<6: im=Image.blend(prev,im,(f+1)/6)
                proc.stdin.write(im.tobytes())
            prev=im
            sample=render(idx,.85)
            sheet.paste(sample.resize((240,427)),((idx%3)*240,(idx//3)*640))
            sample.save(ROOT/f'ui-scene-{idx+1:02}.jpg',quality=95)
            print(f'UI scene {idx+1}/6 rendered',flush=True)
        proc.stdin.close()
        if proc.wait(): raise RuntimeError('FFmpeg encoding failed')
    sheet.save(ROOT/'ui-contact-sheet.jpg',quality=95)
    render(2,.85).save(ROOT/'ui-poster.jpg',quality=95)
    (ROOT/'ui-metadata.json').write_text(json.dumps({'duration_seconds':30,'width':W,'height':H,'fps':FPS,'audio':False,'description':'UI reproduction, not actual Android footage'},indent=2),encoding='utf-8')
    print('Silent UI video complete: 30 seconds, 720x1280, no audio track.',flush=True)

if __name__=='__main__': main()
