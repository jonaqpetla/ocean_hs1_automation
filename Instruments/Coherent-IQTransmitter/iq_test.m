%% Class Test
dev = Coherent_IQ_Transmitter('192.168.0.224', 'IQTransmitter', 'on');
%% ok
modulator = ['XI'; 'XQ';'XP']
for i= 1:length(modulator)
    dev.setAutoBiasON(modulator(i,:));
end
%%
modulator = ['XI'; 'XQ';'XP'];
for i= 1:length(modulator)
    x = dev.checkAutoBias(modulator(i,:));
    if strcmpi(x, 'on')
        stat = 1;
    else
        stat = 0;
    end
end
stat

%% ok
% check dev.limits storage 
% dev.setWavelength(1552)
num2str(dev.wavelengthDevLimits(1,:))
dev.getSetWavelength_nm(1)
pause(10)
dev.getSetWavelength_nm(1)
%% ok
dev.setPower(13.1)
dev.getSetPower()
pause(10)
dev.getMeasuredPower(1)
%% ok
dev.powerOn()
dev.checkPowerState(1)
%%
dev.getModulatedOutputPower_dBm()
%%
dev.closeDevice()
%% 
dev.queryCommand('SOUR:CHAN1:POW? ACT')
% MAKE FUNCTION

%% Commands
% commands for iq transmitter
% bias
% wavelength wait 10s after setting to reach 
% power wait 10s after setting to reach -- stop and start timers for this (maybe loading screen on gui label) NO start/dtop fcn

dev = VISA_Instrument('TCPIP::192.168.0.224::INSTR')
%%
dev.QueryString('*IDN?')
%%
dev.SetTimeoutMilliseconds()
%%
dev.Write('SOUR:CHAN1:WAV 1.55000e-06')

%%
dev.QueryString('SOUR:CHAN1:POW? SET')
%% 
dev.Write('SOUR:CHAN1:POW 15.1')

%% 
%looping timer
modulator = ['XI'; 'XQ';'XP']
for i= 1:3
    dev.QueryString(['ABC:',modulator(i,:),':PILOT?'])
end
%%
dev.QueryString(['ABC:XI:BIAS? SET'])
%% abc output pow
dev.QueryString('ABC:PDP?')
%%
dev.Write('OUTP:CHAN1:STATE ON')
%%
dev.Close()

