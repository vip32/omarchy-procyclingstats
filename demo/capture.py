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
    until=time.monotonic()+12
    while time.monotonic()<until:
        if predicate(): return
        time.sleep(.1)
    raise RuntimeError('Plugin did not reach the expected state')

def interrupted(*_): raise KeyboardInterrupt()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,default=ROOT/'preview.png')
    p.add_argument('--compact',action='store_true')
    args=p.parse_args()
    for cmd in ('omarchy-shell','hyprctl','grim'):
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
    recovery=runtime/'omarchy-pcs-demo-recovery'
    layers=json.loads(run('hyprctl','layers','-j'))
    shell_pids=sorted({item['pid'] for m in layers.values() for level in m['levels'].values() for item in level if item.get('namespace','').startswith('omarchy')})
    recovery.mkdir(mode=0o700) # refuse stale recovery records
    config=Path.home()/'.config/omarchy/shell.json'
    shutil.copy2(config,recovery/'shell.json')
    install=Path.home()/'.config/omarchy/plugins'/ID
    (recovery/'state.json').write_text(json.dumps({'workspace':original_workspace,'panel':panel_state,
        'installedCommit':run('git','-C',str(install),'rev-parse','HEAD'),
        'shellPids':shell_pids,
        'cursor':run('hyprctl','cursorpos','-j')},indent=2))
    for sig in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP): signal.signal(sig,interrupted)
    restored=False
    try:
        wait_for(lambda:not status()['loading'])
        if ipc(ID,'demo','true')!='true': raise RuntimeError('Could not enable demo')
        wait_for(lambda:status()['demo'] and status()['races']==4)
        run('hyprctl','dispatch',f'hl.dsp.focus({{ workspace = "{workspace}" }})')
        mode='compact' if args.compact else 'expand'
        ipc(ID+'.panel',mode)
        wait_for(lambda:status(ID+'.panel')['opened'] and status(ID+'.panel')['expanded'] != args.compact)
        geometry=status(ID+'.panel')['geometry']
        # Wait only for the native panel fade-in after readiness is established.
        time.sleep(.2)
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
            ipc(ID+'.panel','expand' if panel_state['expanded'] else 'compact')
            if not panel_state['opened']: ipc(ID+'.panel','close')
            if status()['demo']: raise RuntimeError('Demo remains enabled')
            restored=True
        finally:
            if restored:
                shutil.rmtree(recovery)
            else:
                print('Restoration incomplete. Recovery state:',recovery)

if __name__=='__main__':main()
