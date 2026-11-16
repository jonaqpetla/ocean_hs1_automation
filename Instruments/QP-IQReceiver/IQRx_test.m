%% test commands
dev = VISA_Instrument('TCPIP::192.168.0.11::INSTR')
%%
dev.QueryString('*IDN?')
dev.QueryString('SLOT1:IDN?')
%%
dev.QueryString('SOUR2:CHAN1:POW? ACT') % ACT 
%%
dev.Write('SOUR2:CHAN1:POW 11')
%%
dev.QueryString('SOUR2:CHAN1:WAV? SET') % ACT
%%
dev.Write('SOUR2:CHAN1:WAV 1.540000e-06') % nm *e-9
%%
dev.QueryString('OUTP2:CHAN1:STATE?')
%%
dev.Write('OUTP2:CHAN1:STATE OFF')
%%
dev.QueryString('SLOT1:OPC?')
dev.QueryString('*ESR?')
%%
dev.QueryString('SENS1:SIG? ACT')
%%
dev.QueryString('MODU1 :OPT?')
%%
dev.Close()
%% test class
dev = QP_IQRx('192.168.0.11', 2, 'QP-Laser', 'on');
%%
dev.getActualPower_dBm(1)
%%
dev.getSetPower_dBm(1);
%%
dev.setPower_dBm(13, 1)
%%
dev.setWavelength_nm(1, 1550);
%%
dev.getSetWavelength_nm(1);
dev.getActualWavelength_nm(1);
%%
dev.getReceiverPower_dBm()
%%
dev.powerON(1)
dev.checkProgramStatus()
%%
tic
dev.checkPowerState(1)
toc
%%
dev.powerOFF(1)
%%
dev.closeDevice()