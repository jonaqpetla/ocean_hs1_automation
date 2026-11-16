classdef Keysight_M8195A < handle
    properties
        devHandle
        devPrintName
        printMode
        headerLine
    end
    properties(GetAccess = public, SetAccess = private)
        voltageDevLimits  % make individual limits
        voltageSafetyLimits
    end
    properties (Access = private)
        channels
    end
    methods
        %% Constructor
        function dev = Keysight_M8195A(IPAddress, instID, dispName, printMode)
            arguments
                IPAddress char = 'DESKTOP-IUT855J'
                instID {mustBeNumeric} = 0
                dispName char = 'Keysight AWG'
                printMode char {mustBeMember(printMode, ['on', 'off', 'ON', 'OFF', 'On', 'Off'])} = 'on'
            end
            try
                dev.devHandle = VISA_Instrument(['TCPIP0::', IPAddress,'::hislip', num2str(instID),'::INSTR']);
            catch ME
                error ('Error initializing %s:\n%s', dispName, ME.message);
            end

            dev.devPrintName = dispName;
            dev.headerLine = ['---------------------- ',dev.devPrintName,' ----------------------'];  

            idnResponse = dev.queryCommand('*IDN?');
            disp(dev.headerLine)
            % Verify device
            disp(['Instrument Connected : ', idnResponse]);
            if contains(idnResponse, 'Keysight', 'IgnoreCase',true)
                disp('Keysight AWG successfully connected')
            else
                dev.closeDevice();
                error('Failed to connect to Keysight AWG')
            end

            dev.channels = 4;
            
            if strcmpi(printMode, 'on')
                dev.printMode = 1;
            else
                dev.printMode = 0;
            end

            dev.findLimits();

            dev.setInitialConditions(); % Set initial conditions for the AWG          
        end

        %% Run/Stop
        function run(dev)
            % Start the AWG
            dev.writeCommand('INIT:IMM');
        end

        function stop(dev)
            % Stop the AWG
            dev.writeCommand('ABOR');
        end

        function status = checkRunStatus(dev)
            % Check the run status of the AWG
            value = str2double(dev.queryCommand('STAB:SEQ:STAT?'));
            status = bitand(bitshift(value, -(25-1)), 3);
            if dev.printMode
                dev.printMiniHeader(['Run status is ', status]);
            end
        end

        %% Output enable/disable
        function enableOutput(dev, channel)
            % Enable the output of the AWG
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 4), mustBePositive}
            end
            dev.writeCommand(['OUTP',num2str(channel),' ON']);
        end

        function disableOutput(dev, channel)
            % Disable the output of the AWG
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 4), mustBePositive}
            end
            dev.writeCommand(['OUTP',num2str(channel),' OFF']);
        end

        function value = checkOutput(dev, channel)
            % Check the output status of the AWG
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 4), mustBePositive}
            end
            value = dev.queryCommand(['OUTP',num2str(channel),'?']);
            if dev.printMode
                dev.printMiniHeader(['Output status of channel ', num2str(channel), ' is ', value]);
                % disp(['Output status of channel ', num2str(channel), ' is ', value]);
            end
        end

        %% Voltage
        function setVoltage(dev, channel, voltage)
            % Set the voltage of a channel
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 4), mustBePositive}     % I
                voltage {mustBeNumeric, mustBeNonnegative}
            end
            dev.checkVoltageLimits(channel, voltage);
            dev.writeCommand(['VOLT',num2str(channel),' ',num2str(voltage)]);
        end

        function value = getSetVoltage(dev, channel)
            % Get the voltage set on a channel
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 4), mustBePositive}
            end
            value = str2double(dev.queryCommand(['VOLT',num2str(channel),'?']));
            if dev.printMode
                dev.printMiniHeader(['Voltage set to ', num2str(value), ' V'])
            end
        end

        %% Clock
        function setInitialConditions(dev)
            % Set the clock parameters
            dev.writeCommand('SOUR:ROSC:FREQ 10e6');
            dev.writeCommand('SOUR:ROSC:RANG RANG1');
            dev.writeCommand('SOUR:ROSC:SOUR EXT');
            dev.writeCommand('OUTP:ROSC:SOUR SCLK2');
        end

        %% Load File
        function loadFile(dev, fileName)
            % Load a file to the AWG
            % The file should be in the MAT89600 format (.mat -v6)
            % It should have a header with XDelta, XOffset and Y, which contains the complex data
            arguments
                dev
                fileName char
            end
                if dev.printMode
                    dev.printMiniHeader(['Loading file: ', fileName]);
                end
                dev.writeCommand('*CLS')
                dev.writeCommand('TRAC1:DEL 1');
                dev.writeCommand('TRAC4:DEL 1');
                dev.writeCommand('TRAC1:DEF 1,32768');
                dev.writeCommand('TRAC4:DEF 1,32768');
                dev.writeCommand(['TRAC1:IMP 1,"', fileName, '", MAT89600, IONLY, OFF']);
                dev.writeCommand(['TRAC4:IMP 1,"', fileName, '", MAT89600, QONLY, OFF']);
                dev.writeCommand('TRAC1:SEL 1');
                dev.writeCommand('TRAC4:SEL 1');
                err = dev.queryCommand('SYST:ERR?'); % Check for errors
                if contains(err, 'No error','IgnoreCase',true)
                else
                    error(err)
                end
        end

        %% Set limits
        function setVotlageSafetyLimits(dev, channel, value)
            % Sets software limit for volatge
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 4), mustBePositive}
                value {mustBeNumeric, mustBeNonnegative}                    
            end
            try
                dev.checkVoltageDevLimits(channel, value)
                dev.voltageSafetyLimits(channel) = value;
            catch ME
                error('Error setting voltage safety limits:\n%s',ME.message)
            end
        end

        %% Destructor
        function closeDevice(dev)
            % Close connection to the instrument
            dev.devHandle.Close();
        end

        %% Write/Query Commands
        function writeCommand(dev,inputText)
            % Write command to the instrument. Uses Write() function from VISA_Instrument class
            dev.devHandle.Write(inputText);
        end
        
        function output= queryCommand(dev,inputText)
            % Query command to the instrument. Uses QueryString() function from VISA_Instrument class
            output = dev.devHandle.QueryString(inputText);
        end
    end

    methods (Access = private)
        %% Limits
        function dev = findLimits(dev)
            % Get the device limits
            % check commmands
            for i = 1:(dev.channels)
                dev.voltageDevLimits(i,1) = str2double(dev.queryCommand(['VOLT', num2str(i), '? MIN']));
                dev.voltageDevLimits(i,2) = str2double(dev.queryCommand(['VOLT', num2str(i), '? MAX']));
            end
            dev.voltageSafetyLimits = dev.voltageDevLimits;
        end

        function checkVoltageLimits(dev, channel, val)
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 4), mustBePositive}
                val {mustBeNumeric, mustBeNonnegative}
            end
            % Checks input voltage agianst safety limits defined by the user
            if(val > dev.voltageSafetyLimits(channel,2) || val < dev.voltageSafetyLimits(channel,1))
                % throw(MException());
                error("%s: Voltage %.3f V outside safety limits set by user", dev.devPrintName, val)
            end
        end

        function checkVoltageDevLimits(dev, channel, val)
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 4), mustBePositive}
                val {mustBeNumeric, mustBeNonnegative}
            end
            % Checks input voltage agianst the device safety limits
            if(val > dev.voltageDevLimits(channel,2) || val < dev.voltageDevLimits(channel,1))
                error("%s: Voltage %.3f V outside device safety limits", dev.devPrintName, val)
            end
        end

        %% Print 
        function printMiniHeader(dev, text)
            disp(strcat('Log from ## ',dev.devPrintName,' @ ',string(datetime('now')),' :'));
            disp(text);
        end
    end
end