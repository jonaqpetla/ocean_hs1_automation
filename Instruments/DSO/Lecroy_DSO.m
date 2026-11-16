classdef Lecroy_DSO < handle
    properties
        devHandle
        devPrintName
        printMode
        headerLine
        maxWaitTime = 300 % Maximum wait time for operations in seconds
    end
    properties (GetAccess = public, SetAccess = private)
        % Properties that can be accessed by external functions
        wavelengthDevLimits
        frequencyDevLimits
        powerDevLimits
        powerSafetyLimits
    end
    properties (Access = private)
        channels
    end

    methods
        %% Constructor
        function dev = Lecroy_DSO(IPAddress, dispName, printMode)
            arguments
                IPAddress char
                dispName char = 'Lecroy DSO'
                printMode char {mustBeMember(printMode, ['on', 'off', 'ON', 'OFF', 'On', 'Off'])} = 'on'
            end
            try
                dev.devHandle = VISA_Instrument(['TCPIP::', IPAddress, '::INSTR']);
            catch ME
                error ('Error initializing %s:\n%s', dispName, ME.message);
            end

            dev.devPrintName = dispName;
            dev.headerLine = ['---------------------- ',dev.devPrintName,' ----------------------'];  

            dev.channels = 1;

            idnResponse = dev.queryCommand('*IDN?');
            disp(dev.headerLine)
            % Verify device
            disp(['Instrument Connected : ',idnResponse ]);
            if contains(idnResponse, 'Lecroy', 'IgnoreCase',true)
                disp('Lecroy DSO successfully connected')
            else
                dev.closeDevice();
                disp('Failed to connect to Lecroy DSO')
            end

            dev.setInitialConditions(); % Set initial conditions for the device

            if strcmpi(printMode, 'on')
                dev.printMode = 1;
            else
                dev.printMode = 0;
            end
        end

        %% Trigger
        function triggerReading(dev)
            dev.writeCommand('TRMD SINGLE;ARM;FRTR');
        end

        %% Get Waveform
        function waveform = getWaveform(dev, channel)
            arguments
                dev
                channel {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(channel, 16)} = 1 % Default to channel 1
            end
            % Get waveform data from the specified channel
            dev.writeCommand(['C', num2str(channel),':WAVEFORM? DAT1'])
            char(dev.devHandle.Read(5));
            % dev.devHandle.ReadBufferSize();
            waveform = typecast(dev.devHandle.ReadBinaryDataBlock(), 'int8');
            % conversion to whatever DSO is using
        end

        function waveform = getNewWaveform(dev)
            % Get new waveform data from the specified channel
            dev.triggerReading(); % Trigger a new reading
            timeElapsed = dev.waitForOperationComplete(); % Wait for the operation to complete
            if dev.printMode
                dev.printMiniHeader(['Waveform acquisition completed in ', num2str(timeElapsed), ' seconds']);
            end
            waveform = cell(1, 16); % Initialize waveform cell array
            % waveform = zeros(1, 16); % Initialize waveform array
            for i = 1:16
                waveform{i} = dev.getWaveform(i); % Get the waveform data
            end 
        end

        %% Save 
        function saveWaveform(dev, channel)
            % Save waveform to file
            arguments
                dev
                channel {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(channel, 1)}
            end
            dev.writeCommand(['STORE C', num2str(channel), ',FILE']);
        end
         
        function selectFile(dev, filepth)
            % Select location to save file to
            arguments
                dev
                filepth char
            end
            [device, filename] = regexp(filepth, ':\', 'split');
            dev.writeCommand(["DIR DISK,", device, ",ACTION,CREATE,'", filename, "'"]);
        end

        function saveWaveformToFile(dev, waveform, fileName)
            % Save waveform to file
            arguments
                dev
                waveform
                fileName char
            end
            save(fileName, 'waveform'); % Save waveform data to .mat file
        end

        %% Time division
        function setTimeDiv_ns(dev, timeDiv)
            % Set time division in nanoseconds
            arguments
                dev
                timeDiv {mustBeNumeric, mustBePositive}
            end
            dev.writeCommand(['TDIV ', num2str(timeDiv),'NS']);
        end

        function value = getSetTimeDiv_s(dev)
            % Get time division in s
            value = str2double(dev.queryCommand('TDIV?'))*1e9;
            if dev.printMode
                dev.printMiniHeader(['Time division set to ', num2str(value),' ns'])
            end
        end

        %% Voltage division
        function setVoltageDiv_V(dev, voltDiv)
            % Set voltage division in V
            arguments
                dev
                voltDiv {mustBeNumeric, mustBePositive}
            end
            dev.writeCommand(['VDIV ', num2str(voltDiv),'V']);
        end

        function value = getSetVoltageDiv_V(dev)
            % Get voltage division in V
            value = str2double(dev.queryCommand('VDIV?'));
            if dev.printMode
                dev.printMiniHeader(['Voltage division set to ', num2str(value), ' mV'])
            end
        end
        %% Trigger delay
        function setTriggerDelay_ns(dev, delay)
            % Set trigger delay in nanoseconds
            arguments
                dev
                delay {mustBeNumeric, mustBeReal}
            end
            dev.writeCommand(['TRIG_DELAY ', num2str(delay),'NS']);
        end
        function value = getSetTriggerDelay_s(dev)
            % Get trigger delay in seconds
            value = str2double(dev.queryCommand('TRIG_DELAY?'))*1e9;
            if dev.printMode
                dev.printMiniHeader(['Trigger Delay set to ', num2str(value),' ns'])
            end
        end

        %% Set initial conditions
        function setInitialConditions(dev)
            % Set initial conditions for the device
            dev.writeCommand('COMM_HEADER OFF'); % Disable communication header
            dev.writeCommand('COMM_ORDER HI'); % Set communication order
            dev.writeCommand('CFMT DEF9,BYTE,BIN'); % Set data format to DEF9
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
        
        function output = queryCommand(dev,inputText)
            % Query command to the instrument. Uses QueryString() function from VISA_Instrument class
            output = dev.devHandle.QueryString(inputText);
        end
    end
    methods (Access = private)
        function data = parseDEF9Block(raw)
            % raw: uint8 array from instrument (e.g., from dev.devHandle.Read(...))
            % Find the header
            if raw(1) ~= '#'
                error('Not a valid DEF block');
            end
            numDigits = str2double(char(raw(2)));
            byteCount = str2double(char(raw(3:2+numDigits))');
            dataStart = 3 + numDigits;
            dataEnd = dataStart + byteCount - 1;
            binaryData = raw(dataStart:dataEnd);
            % Convert to single-precision float (IEEE754)
            data = typecast(uint8(binaryData), 'single');
        end

         %% Waits for trigger command to complete
        function timeElapsed = waitForOperationComplete(dev)
            flag = 0;
            tic;
            while flag ==0
                try
                    flag = str2num(dev.queryCommand('*OPC?'));
                catch
                    timeElapsed = toc;
                    if timeElapsed>dev.maxWaitTime
                        error([dev.devPrintName,' : Maximum wait time exceeded for acquisition. ' ...
                            'Edit property /obj.maxWaitTime/ for increasing acquisition wait time, if required ']);
                    end
                end
            end
            timeElapsed = toc;
        end

        %% Print
        function printMiniHeader(dev, text)
            disp(strcat('Log from ## ',dev.devPrintName,' @ ',string(datetime('now')),' :'));
            disp(text);
        end
    end

    %% Laser functions
    methods (Access = public)
        %% Frequency
        function setFrequency(dev, channel, frequency)
            % Set the laser frequency
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive} 
                frequency double {mustBePositive}
            end
             % If frequency is outside device limits, set to the closest limit
            if (frequency > dev.frequencyDevLimits(1, channel))
            frequency = dev.frequencyDevLimits(1, channel);
            disp(['Frequency set to ',num2str(frequency),' Hz. Maximum frequency is ',num2str(dev.frequencyDevLimits(1, channel)),' Hz'])
            elseif (frequency < dev.frequencyDevLimits(2, channel))
            frequency = dev.frequencyDevLimits(2, channel);
            disp(['Frequency set to ',num2str(frequency),' Hz. Minimum frequency is ',num2str(dev.frequencyDevLimits(2, channel)),' Hz'])
            end
            dev.writeCommand(['VBS app.OMA.LaserFrequency=', frequency]);
            if dev.printMode
                dev.printMiniHeader(['Frequency set to ', num2str(value), ' THz'])
            end
        end

        function getSetFrequency(dev, channel)
            % Get the current laser frequency
            response = str2double(dev.queryCommand('VBS? return=app.OMA.LaserFrequency'))*1e-12;
            if dev.printMode
                dev.printMiniHeader(['Current Laser Frequency: ', num2str(response), ' THz']);
            end
        end
        %% Wavelength
        function setWavelength(dev, channel, wavelength)
            % Set the laser wavelength
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
                wavelength double {mustBePositive}
            end
            % If wavelength is outside device limits, set to the closest limit
            if (wavelength > dev.wavelengthDevLimits(1, channel))
                wavelength = dev.wavelengthDevLimits(1, channel);
                disp(['Wavelength set to ',num2str(wavelength),' nm. Maximum wavelength is ',num2str(dev.wavelengthDevLimits(1, channel)),' nm'])
            elseif (wavelength < dev.wavelengthDevLimits(2, channel))
                wavelength = dev.wavelengthDevLimits(2, channel);
                disp(['Wavelength set to ',num2str(wavelength),' nm. Minimum wavelength is ',num2str(dev.wavelengthDevLimits(2, channel)),' nm'])
            end
            dev.writeCommand(['VBS app.OMA.LaserWavelength=', num2str(wavelength)]);
            if dev.printMode
                dev.printMiniHeader(['Wavelength set to ', num2str(value), ' nm'])
            end
        end
        function getSetWavelength(dev, channel)
            % Get the current laser wavelength
            response = str2double(dev.queryCommand('VBS? return=app.OMA.LaserWavelength'))*1e9;
            if dev.printMode
                dev.printMiniHeader(['Current Laser Wavelength: ', num2str(response), ' nm']);
            end
        end
        %% Power
        function setPower_dBm(dev, channel, power)
            % Set the laser power
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
                power double {mustBeNonnegative}
            end
            dev.writeCommand(['VBS app.OMA.LaserPower=', num2str(power)]);
            if dev.printMode
                dev.printMiniHeader(['Power set to ', num2str(value), ' THz'])
            end
        end

        function getSetPower_dBm(dev, channel)
            % Get the current laser power
            response = str2double(dev.queryCommand('VBS? return=app.OMA.LaserPower'));
            if dev.printMode
                dev.printMiniHeader(['Current Laser Power: ', num2str(response), ' dBm']);
            end
        end

        %% Set limits
        function dev = setPowerSafetyLimits(dev, channel, min, max)
            % Sets software limit for power
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
                min {mustBeNumeric, mustBeNonnegative}
                max {mustBeNumeric, mustBeNonnegative}
            end
            try
                dev.checkPowerDevLimits(channel, min);
                dev.checkPowerDevLimits(channel, max);
                dev.powerSafetyLimits(channel,:) = [min, max];
                if dev.printMode
                    dev.printMiniHeader(['Power safety limits for channel ', num2str(channel), ': [', num2str(min), ', ', num2str(max), '] dBm']);
                end
            catch ME
                error('Error setting power safety limits:\n%s', ME.message);
            end
        end

        %% On/Off
        function powerON(dev, channel)
            % Turn on the power
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
            end
            pass
        end
        
        function powerOFF(dev, channel)
            % Turn off the power
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
            end
            pass
        end
    end
     methods (Access = private)
        %% Limits
        function dev = findLimits(dev)
            % Find the device limits
            for i = 1:(dev.channels)
                % Get the power device limits
                dev.powerDevLimits(i,1) = str2double(dev.queryCommand(['SOUR',num2str(dev.slotNo), ':CHAN', num2str(i), ':POW? MIN']));
                dev.powerDevLimits(i,2) = str2double(dev.queryCommand(['SOUR',num2str(dev.slotNo), ':CHAN', num2str(i), ':POW? MAX']));
                % Get the wavelength device limits
                dev.wavelengthDevLimits(i,1) = str2double(dev.queryCommand(['SOUR',num2str(dev.slotNo), ':CHAN', num2str(i), ':WAV? MIN']))*1e9;
                dev.wavelengthDevLimits(i,2) = str2double(dev.queryCommand(['SOUR',num2str(dev.slotNo), ':CHAN', num2str(i), ':WAV? MAX']))*1e9;
            end
            dev.powerSafetyLimits = dev.powerDevLimits;
        end
        
        function checkPowerLimits(dev, channel, val)
            % Checks input power against safety limits defined by the user
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
                val {mustBeNumeric, mustBeNonnegative}
            end
            if(val > dev.powerSafetyLimits(channel, 2) || val < dev.powerSafetyLimits(channel, 1))
                error("%s: Power %.3f dBm outside safety limits set by user", dev.devPrintName, val)
            end
        end
        
        function checkPowerDevLimits(dev, channel, val)
            % Checks input power against the device safety limits
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
                val {mustBeNumeric, mustBeNonnegative}
            end
            if(val > dev.powerDevLimits(channel, 2) || val < dev.powerDevLimits(channel, 1))
                error("%s: Power %.3f dBm outside device safety limits", dev.devPrintName, val)
            end
        end
     end
end