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

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,default=ROOT/'preview.png')
    p.add_argument('--day',type=int,choices=[-1,0,1],default=0,help='Yesterday, today or tomorrow')
    p.add_argument('--compact',action='store_true')
    p.add_argument('--events',action='store_true',help='Capture the race-events tab')
    p.add_argument('--settings',action='store_true',help='Capture the settings screen')
    p.add_argument('--settings-section',choices=['filters','refresh'],default='filters')
    p.add_argument('--warning',choices=['blocked','rate-limited','offline'],help='Show a fictional connection warning')
    p.add_argument('--race-index',type=int,default=0,choices=range(4))
    args=p.parse_args()
    for cmd in ('omarchy-shell','hyprctl','grim','git'):
        if not shutil.which(cmd): p.error('Missing '+cmd)
    panel_state=status(ID+'.panel')
    if status()['demo']: p.error('Demo is already active; restore it first with demo false')
    monitors=json.loads(run('hyprctl','monitors','-j'))
    if len(monitors)!=1 or monitors[0]['transform']!=0:
        p.error('Capture currently supports one unrotated monitor')
    if any(c.get('class')=='hyprlock' for c in json.loads(run('hyprctl','clients','-j'))):
        p.error('Unlock the session before capturing')
    original_workspace=monitors[0]['activeWorkspace']['id']
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
        wait_for(lambda:not status()['loading'])
        if ipc(ID,'demo','true')!='true': raise RuntimeError('Could not enable demo')
        wait_for(lambda:status()['demo'] and status()['races']==4)
        run('hyprctl','dispatch',f'hl.dsp.focus({{ workspace = "{workspace}" }})')
        mode='compact' if args.compact else 'expand'
        ipc(ID+'.panel','showDay',str(args.day))
        ipc(ID+'.panel','selectRace',str(args.race_index))
        ipc(ID+'.panel',mode)
        ipc(ID+'.panel','setDetailView','events' if args.events else 'overview')
        if args.settings: ipc(ID+'.panel','settings')
        if args.warning: ipc(ID,'demoWarning',args.warning)
        wait_for(lambda:status(ID+'.panel')['opened'] and status(ID+'.panel')['expanded'] != args.compact)
        if args.settings:
            ipc(ID+'.panel','settingsSection',args.settings_section)
            if args.settings_section=='refresh':
                wait_for(lambda:status(ID+'.panel')['scrollY']>0)
        geometry=status(ID+'.panel')['geometry']
        # Wait only for the native panel fade-in after readiness is established.
        time.sleep(.6)
        if not status(ID+'.panel')['demo']: raise RuntimeError('Refusing to capture non-demo data')
        mon=monitors[0]
        x,y=round(geometry['x']+mon['x']),round(geometry['y']+mon['y'])
        area=f"{x},{y} {round(geometry['width'])}x{round(geometry['height'])}"
        args.output.parent.mkdir(parents=True,exist_ok=True)
        run('grim','-g',area,str(args.output))
        print(args.output)
    finally:
        try:
            ipc(ID+'.panel','close')
            if ipc(ID,'demo','false')!='true': raise RuntimeError('Could not restore live fetching')
            run('hyprctl','dispatch',f'hl.dsp.focus({{ workspace = "{original_workspace}" }})')
            run('hyprctl','dispatch',f'hl.dsp.cursor.move({{ x = {original_cursor["x"]}, y = {original_cursor["y"]} }})')
            wait_for(lambda:not status()['loading'])
            ipc(ID+'.panel','showRaces')
            ipc(ID+'.panel','showDay',str(panel_state.get('dayOffset',0)))
            wait_for(lambda:not status()['loading'])
            ipc(ID+'.panel','restoreView',panel_state.get('filter','Races'),panel_state['selected'],str(panel_state['expanded']).lower(),str(panel_state['opened']).lower())
            ipc(ID+'.panel','setDetailView',panel_state.get('detailView','overview'))
            if panel_state.get('settingsOpen'): ipc(ID+'.panel','settings')
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
