#!/usr/bin/python3
"""Capture the installed plugin's fictional demo and restore desktop state."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

ID='io.github.vip32.procyclingstats'
ROOT=Path(__file__).resolve().parents[1]

def run(*args):
    return subprocess.check_output(args,text=True,timeout=10).strip()

def ipc(target,method,*args):
    return run('omarchy-shell',target,method,*args)

def status(target=ID):
    return json.loads(ipc(target,'status'))

def wait_for(predicate):
    until=time.monotonic()+25
    while time.monotonic()<until:
        if predicate(): return
        time.sleep(.1)
    raise RuntimeError('Plugin did not reach the expected state')

def interrupted(*_): raise KeyboardInterrupt()

def dashboard_windows():
    return [c for c in json.loads(run('hyprctl','clients','-j')) if c.get('title')=='ProCyclingStats — Race dashboard']

def verify_window():
    target=ID+'.panel'
    before=status(target)
    def same_view():
        current=status(target)
        for key in ('selected','dayOffset','filter','expanded','detailView','settingsOpen','classificationTitle','expandedGroups','archiveMode','archiveCount'):
            if current[key]!=before[key]: raise RuntimeError('Window transition changed '+key)
    ipc(target,'detach')
    wait_for(lambda:len(dashboard_windows())==1)
    if dashboard_windows()[0]['floating']: raise RuntimeError('Dashboard did not tile on this host')
    same_view()
    address=dashboard_windows()[0]['address']
    ipc(target,'open');ipc(target,'open')
    if len(dashboard_windows())!=1 or dashboard_windows()[0]['address']!=address:
        raise RuntimeError('Repeated open duplicated the dashboard')
    used={w['id'] for w in json.loads(run('hyprctl','workspaces','-j'))}
    away=next(i for i in range(110,130) if i not in used)
    run('hyprctl','dispatch',f'hl.dsp.focus({{ workspace = "{away}" }})')
    ipc(target,'open')
    wait_for(lambda:json.loads(run('hyprctl','activewindow','-j')).get('address')==address)
    same_view()
    # Exercise a real geometry change, then return to the normal tiled state.
    run('hyprctl','dispatch','hl.dsp.window.float({action="toggle"})')
    wait_for(lambda:dashboard_windows()[0]['floating'])
    same_view()
    run('hyprctl','dispatch','hl.dsp.window.float({action="toggle"})')
    wait_for(lambda:not dashboard_windows()[0]['floating'])
    # A real compositor close must retain the QML view and keep the shell alive.
    wait_for(lambda:json.loads(run('hyprctl','activewindow','-j')).get('address')==address)
    run('hyprctl','dispatch','hl.dsp.window.close()')
    wait_for(lambda:not status(target)['windowVisible'])
    same_view()
    ipc(target,'open')
    wait_for(lambda:len(dashboard_windows())==1 and status(target)['windowVisible'])
    same_view()
    ipc(target,'dock')
    wait_for(lambda:not dashboard_windows() and not status(target)['detached'])
    same_view()
    print('Window smoke check passed: tiled, one instance, cross-workspace focus, resize, native close/reopen, dock and view retention.')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,default=ROOT/'preview.png')
    p.add_argument('--day',type=int,choices=[-1,0,1],default=0,help='Yesterday, today or tomorrow')
    p.add_argument('--calendar',choices=['recent','upcoming'],help='Browse fictional races beyond adjacent days')
    p.add_argument('--window',action='store_true',help='Capture the detached desktop window')
    p.add_argument('--verify-window',action='store_true',help='Exercise dock, reopen, focus and close with fictional data')
    p.add_argument('--compact',action='store_true')
    p.add_argument('--reveal',action='store_true',help='Reveal fictional finished results')
    p.add_argument('--events',action='store_true',help='Capture the race-events tab')
    p.add_argument('--settings',action='store_true',help='Capture the settings screen')
    p.add_argument('--settings-section',choices=['filters','refresh','spoilers'],default='filters')
    p.add_argument('--warning',choices=['blocked','rate-limited','offline'],help='Show a fictional connection warning')
    p.add_argument('--race-index',type=int,default=0,choices=range(4))
    args=p.parse_args()
    for cmd in ('omarchy-shell','hyprctl','grim','git'):
        if not shutil.which(cmd): p.error('Missing '+cmd)
    panel_state=status(ID+'.panel')
    if status()['demo']: p.error('Demo is already active; restore it first with demo false')
    monitors=json.loads(run('hyprctl','monitors','-j'))
    monitor=next((m for m in monitors if m['name']==panel_state['geometry']['screen']),None)
    if not monitor or monitor['transform']!=0 or not monitor.get('focused'):
        p.error('Focus the unrotated monitor containing the plugin before capturing')
    if any(c.get('class')=='hyprlock' for c in json.loads(run('hyprctl','clients','-j'))):
        p.error('Unlock the session before capturing')
    original_workspace=monitor['activeWorkspace']['id']
    used={w['id'] for w in json.loads(run('hyprctl','workspaces','-j'))}
    workspace=next(i for i in range(90,110) if i not in used)
    runtime=Path(os.environ.get('XDG_RUNTIME_DIR','/tmp'))
    stale=list(runtime.glob('omarchy-pcs-demo-recovery*'))
    if stale: p.error('Stale recovery state: '+', '.join(str(p) for p in stale))
    recovery=Path(tempfile.mkdtemp(prefix='omarchy-pcs-demo-recovery-',dir=runtime))
    layers=json.loads(run('hyprctl','layers','-j'))
    shell_pids=sorted({item['pid'] for m in layers.values() for level in m['levels'].values() for item in level if item.get('namespace','').startswith('omarchy')})
    config=Path.home()/'.config/omarchy/shell.json'
    shutil.copy2(config,recovery/'shell.json')
    install=Path.home()/'.config/omarchy/plugins'/ID
    original_cursor=json.loads(run('hyprctl','cursorpos','-j'))
    (recovery/'state.json').write_text(json.dumps({'workspace':original_workspace,'panel':panel_state,
        'installedCommit':run('git','-C',str(install),'rev-parse','HEAD'),
        'shellPids':shell_pids,
        'cursor':original_cursor},indent=2))
    for sig in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP): signal.signal(sig,interrupted)
    restored=False
    try:
        if panel_state.get('detached'): ipc(ID+'.panel','dock')
        wait_for(lambda:not status()['loading'])
        if ipc(ID,'demo','true')!='true': raise RuntimeError('Could not enable demo')
        wait_for(lambda:status()['demo'] and status()['races']==4)
        run('hyprctl','dispatch',f'hl.dsp.focus({{ workspace = "{workspace}" }})')
        mode='compact' if args.compact else 'expand'
        ipc(ID+'.panel','showDay',str(args.day))
        if args.calendar: ipc(ID+'.panel','calendar',args.calendar)
        ipc(ID+'.panel','selectRace',str(args.race_index))
        ipc(ID+'.panel',mode)
        ipc(ID+'.panel','setDetailView','events' if args.events else 'overview')
        if args.reveal: ipc(ID+'.panel','revealResults')
        if args.settings: ipc(ID+'.panel','settings')
        if args.warning: ipc(ID,'demoWarning',args.warning)
        wait_for(lambda:status(ID+'.panel')['opened'] and status(ID+'.panel')['expanded'] != args.compact)
        if args.settings:
            ipc(ID+'.panel','settingsSection',args.settings_section)
            if args.settings_section in ('refresh','spoilers'):
                wait_for(lambda:status(ID+'.panel')['scrollY']>0)
        if args.verify_window: verify_window()
        if args.window:
            ipc(ID+'.panel','detach')
            wait_for(lambda:len(dashboard_windows())==1)
        geometry=status(ID+'.panel')['geometry']
        # Wait only for the native panel fade-in after readiness is established.
        time.sleep(.6)
        if not status(ID+'.panel')['demo']: raise RuntimeError('Refusing to capture non-demo data')
        mon=next(m for m in monitors if m['name']==geometry['screen'])
        x,y=round(geometry['x']+mon['x']),round(geometry['y']+mon['y'])
        if args.window:
            client=dashboard_windows()[0]
            x,y=client['at'];geometry={'width':client['size'][0],'height':client['size'][1]}
        area=f"{x},{y} {round(geometry['width'])}x{round(geometry['height'])}"
        args.output.parent.mkdir(parents=True,exist_ok=True)
        run('grim','-g',area,str(args.output))
        print(args.output)
    finally:
        try:
            if status(ID+'.panel').get('detached'): ipc(ID+'.panel','dock')
            ipc(ID+'.panel','close')
            if ipc(ID,'demo','false')!='true': raise RuntimeError('Could not restore live fetching')
            run('hyprctl','dispatch',f'hl.dsp.focus({{ workspace = "{original_workspace}" }})')
            run('hyprctl','dispatch',f'hl.dsp.cursor.move({{ x = {original_cursor["x"]}, y = {original_cursor["y"]} }})')
            wait_for(lambda:not status()['loading'])
            ipc(ID+'.panel','showRaces')
            ipc(ID+'.panel','showDay',str(panel_state.get('dayOffset',0)))
            wait_for(lambda:not status()['loading'])
            if panel_state.get('filter')=='Calendar':
                ipc(ID+'.panel','restoreCalendar',panel_state.get('archiveMode','recent'),str(panel_state.get('archiveCount',25)))
                wait_for(lambda:not status()['loading'] and not status(ID+'.panel')['archiveBusy'])
            ipc(ID+'.panel','restoreView',panel_state.get('filter','Races'),panel_state['selected'],str(panel_state['expanded']).lower(),str(panel_state['opened']).lower())
            ipc(ID+'.panel','setDetailView',panel_state.get('detailView','overview'))
            if panel_state.get('settingsOpen'): ipc(ID+'.panel','settings')
            if panel_state.get('detached'): ipc(ID+'.panel','detach')
            ipc(ID+'.panel','restoreScroll',str(panel_state.get('scrollY',0)),str(panel_state.get('settingsCursor',0)))
            if not panel_state['opened']: ipc(ID+'.panel','close')
            if status()['demo']: raise RuntimeError('Demo remains enabled')
            restored=True
        finally:
            if restored:
                shutil.rmtree(recovery)
            else:
                print('Restoration incomplete. Recovery state:',recovery)

if __name__=='__main__':main()
