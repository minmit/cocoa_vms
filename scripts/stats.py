import os
import subprocess
import time
import signal
import sys

ROUT = os.path.expanduser("~/scripts/outputs/r_out.txt")
MG_DIR = os.path.expanduser("~/MoonGen")

def run(respond):
    
    r_out = open(ROUT, 'w')
    mg = os.path.join(MG_DIR, "build/MoonGen")
    mg_src = os.path.join(MG_DIR, "examples/cocoa_dut.lua")
    p = subprocess.Popen([mg, mg_src, "1", "0", "-r", 
                                      "%d" % respond],
                          stdout = r_out, shell=False)     
   
    time.sleep(5)
    rx_started = False
    elapsed = 0
    while (not rx_started) and elapsed < 5:
        time.sleep(1)
        elapsed += 1
        tp = subprocess.Popen(["tail", "-n", "1", ROUT], shell=False, stdout = subprocess.PIPE)
        (line, _) = tp.communicate()
        rx_started = "[Queue" in line and "Mpps" in line and not "StdDev" in line
     
    if elapsed < 5:
        time.sleep(20)
    
    os.kill(p.pid, signal.SIGINT)
    r_out.close()
 
    time.sleep(2)
    if elapsed < 5:
        tp = subprocess.Popen(["tail", "-n", "1", ROUT], shell=False, stdout = subprocess.PIPE)
        (line, _) = tp.communicate() 
        parts = [x.strip() for x in line.split()]
        stdev = int(parts[8][:-1])
        mean = int(parts[10][1:])
        print "RX Stat: ", mean, stdev
    else:
        print "RX Not Working"
 
if __name__ == "__main__":
    run(int(sys.argv[1]))
