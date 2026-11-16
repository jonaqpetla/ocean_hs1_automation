%% Class test
dev = Keysight_M8195A('DESKTOP-IUT855J', 0, 'Keysight AWG', 'on');
% findlimits not saving limits in variable
%% ok
dev.run()
%% ok
dev.stop()
%% ok
dev.setVoltage(1, 0.5)
%%
dev.getSetVoltage(1)
%% ok
dev.enableOutput(4)
%% ok
dev.disableOutput(4)
%%
dev.checkOutput(1)
%%
dev.voltageDevLimits
%%
dev.closeDevice()
%%
dev.loadFile("C:\Users\IQ Tx\Desktop\test2.mat")
%% Command test
dev = VISA_Instrument('TCPIP0::DESKTOP-IUT855J::hislip0::INSTR')
%%
dev.QueryString('*IDN?')
%%
dev.Close()
%%
dev.QueryString('VOLT1?')
%%
dev.Close()
%% ENABLE
dev.QueryString('OUTP1?')
%% START/RUN
dev.Write('*CLS')
dev.Write('INIT:IMM')
dev.QueryString('SYST:ERR?')

%% STOP
dev.Write('*CLS')
dev.Write('ABOR')
dev.QueryString('SYST:ERR?')

%%
dev.Write('*CLS')
dev.Write('INIT:CONT 1;GATE 0')
dev.QueryString('SYST:ERR?')

%SOUR:RO
% CHANGE MAXIMUHN AMPLITUDE
% VOLT1 CHANGES BUT NEEDS UPPER LIMIT - SOFTWARE LIMIT + DEVICE LIMIT
%%
an.i = typecast(dev.QueryBinaryDataBlock('TRAC1:DATA:BLOC? 1,0,32768'),'int8');
an.q = typecast(dev.QueryBinaryDataBlock('TRAC4:DATA:BLOC? 1,0,32768'),'int8');
%%
dev.QueryLongString('TRAC4:DATA? 1,0,32768')

%%
dev.Write('*CLS')
dev.Write('TRAC1:DEL 1')
dev.Write('TRAC4:DEL 1')
dev.QueryString('SYST:ERR?')

%%
dev.Write('*CLS')
dev.Write('TRAC1:DEF 1,32768')
dev.Write('TRAC4:DEF 1,32768')
dev.QueryString('SYST:ERR?')

%%
dev.QueryString('TRAC1:CAT?')
dev.QueryString('TRAC4:CAT?')

%%
dev.Write('*CLS')
txt1 = '"C:\Users\IQ Tx\Desktop\test.mat"'; %QPSK
txt2 = '"C:\Users\IQ Tx\Desktop\test2.mat"'; %16QAM
txt3 = "D:\Rekha\AWG loading data\PRBS15\QAM16_8GBd.mat";
dev.Write(['TRAC1:IMP 1,', txt1, ', MAT89600, IONLY, OFF'])
dev.Write(['TRAC4:IMP 1,', txt1,', MAT89600, QONLY, OFF'])
dev.QueryString('SYST:ERR?')

%%
dev.Write('*CLS')
dev.Write('TRAC1:SEL 1')
dev.Write('TRAC4:SEL 1')
dev.QueryString('SYST:ERR?')

%%
dev.Write('*CLS')
%%
x = str2double(dev.QueryString('STAB:SEQ:STAT?'))
y = bitget(x, 27:28)
z = bitand(bitshift(x, -(25-1)), 3) 
%%
p = typecast(i,'int8');
%%
function OUT = find_value(IN)
    V = IN-'0';
    frc = 1+sum(V(10:32).*2.^(-1:-1:-23));
    pow = sum(V(2:9).*2.^(7:-1:0))-127;
    sgn = (-1)^V(1);
    OUT = sgn * frc * 2^pow;
end