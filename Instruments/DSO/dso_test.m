%% commands
dev = VISA_Instrument('TCPIP::192.168.0.109::INSTR')
%%
dev.QueryString('*IDN?')
%% TIME DIV
dev.Write('TDIV 100NS');
%% TRIGGER
dev.Write('TRMD SINGLE;ARM;FRTR'); 
%% SAVE
dev.Write('STORE ALL_DISPLAYED,FILE');
%% SELECT FILEPATH
% path = 'Users/LeCroyUser/Desktop/dumb'
dev.Write('DIR DISK,HDD,ACTION,CREATE,''TransfeR4''');
%%
dev.Write('DIR DISK,HDD,ACTION,SWITCH,''TransfeR3''');
%% close
dev.Close();
%%
dev.QueryString('STORE_SETUP?')
%%
dev.QueryString('DIR? DISK, HDD')
%% oma frequency
str2double(dev.QueryString('VBS? return=app.OMA.LaserFrequency'))*1e-12
%%
dev.Write('VBS app.OMA.LaserFrequency=193.4145e12')
%% oma power
dev.QueryString('VBS? return=app.OMA.LaserPower')
%%
dev.Write('VBS app.OMA.LaserPower=8.5')
%% oma wavelength
str2double(dev.QueryString('VBS? return=app.OMA.LaserWavelength'))*1e9
%%
dev.Write('VBS app.OMA.LaserWavelength=0.00000155100')
%%
dev.QueryString('VBS? return=app.OMA.LaserOutputStatus')
%%
dev.Write(['VBS app.OMA.EnableOMA=1'])
% query laser power status - on/off
%%
dev.Close()
%% waveform
dev.Write('C16:WAVEFORM? DAT1')
char(dev.Read(5))
dev.ReadBufferSize()
y = typecast(dev.ReadBinaryDataBlock(), 'int8'); % data conversion?? 
% y = dev.ReadBinaryDataBlock();
figure
plot(y)
%% template
dev.Write('TMPL?')
char(dev.Read(dev.ReadBufferSize()))
%% trigger delay
dev.Write('TRIG_DELAY -2.5e-9S')
dev.QueryString('TRIG_DELAY?')
%% voltage division
dev.QueryString('VDIV?')
%% data format
dev.QueryString('CFMT?')
%%
dev.Write('CFMT DEF9,BYTE,BIN') % def9 = data is divided into 8 bit blocks - only option for dso
%% COMM HEADER
dev.Write('COMM_HEADER OFF')
dev.QueryString('COMM_HEADER?')
%%
dev.QueryString('COMM_ORDER?')
%% class

dso = Lecroy_DSO('192.168.0.109');
%% TIME DIV
dso.setTimeDivUS(50);
%% TRIGGER
dso.triggerReading();
%% SAVE
x = dso.getNewWaveform()
% plot(x)
dso.saveWaveformToFile(x,'file.mat')
%% SELECT FILEPATH
dso.selectFile(path);
%% close
dso.closeDevice();
%%
dso.getSetTimeDiv_s()
dso.getSetTriggerDelay_s()
dso.getSetVoltageDiv_V()
%%
dso.getSetFrequency()
dso.getSetWavelength()
dso.getSetPower_dBm()
%%
rec = LecroyRx(dso);
%%
waveform = dso.getNewWaveform();
dso.saveWaveformToFile(waveform, 'file2.mat')