%% test commands
dev = VISA_Instrument('TCPIP::192.168.0.101::INSTR')
%%
dev.QueryString('*IDN?')
dev.QueryString('SLOT1:IDN?')
%%
dev.QueryString('SOUR1:CHAN3:POW? SET') % ACT 
%%
dev.Write('SOUR1:CHAN3:POW 8.2')
%%
dev.QueryString('SOUR1:CHAN1:WAV? SET') % ACT
%%
dev.Write('SOUR1:CHAN1:WAV 1.580000e-06') % nm *e-9
%%
dev.QueryString('SOUR1:CHAN1:FREQ? SET') % ACT
%%
dev.Write('SOUR1:CHAN1:FREQ 1.92e+14') % THz *e12
%%
dev.QueryString('OUTP1:CHAN1:STATE?')
%%
dev.Write('OUTP1:CHAN3:STATE ON')
%%
dev.QueryString('SLOT1:OPC?')
dev.QueryString('*ESR?')
%%
dev.Close()
%% test class
dev = QP_Laser_1200('192.168.0.101', 1, 'QP-Laser', 'on');
%%
dev.getActualPower_dBm(4)
%%
dev.getSetPower_dBm(4)
%%
dev.setPower_dBm(13.5, 4)
%%
dev.setWavelength_nm(4, 1580)
%%
dev.getSetWavelength_nm(4)
dev.getActualWavelength_nm(4)
%%
dev.getSetFrequency_THz(1)
%%
dev.setFrequency_THz(1, 192)
dev.getActualFrequency_THz(1)
%%
dev.powerON(4)
dev.checkProgramStatus()
%%
dev.checkPowerState(4)
%%
dev.powerOFF(4)
%%
dev.closeDevice()
%%
% funky display format for log header