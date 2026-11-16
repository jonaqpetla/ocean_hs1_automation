% check error messages
classdef Coherent_IQ_Transmitter < handle
    properties
        devHandle
        devPrintName
        printMode
        headerLine
    end

    properties (GetAccess = public, SetAccess = private)
        % Properties that can be accessed by external functions
        wavelengthDevLimits
        powerDevLimits
        powerSafetyLimits
    end
    
    methods
        %% Constructor
        function dev = Coherent_IQ_Transmitter(IPAddress, dispName, printMode)
            arguments
                IPAddress char
                dispName char = 'Coherent IQ Transmitter'
                printMode char {mustBeMember(printMode, ['on', 'off', 'ON', 'OFF', 'On', 'Off'])} = 'on'
            end
            try
                dev.devHandle = VISA_Instrument(['TCPIP::', IPAddress, '::INSTR']);
            catch ME
                error ('Error initializing %s:\n%s', dispName, ME.message);
            end

            dev.devPrintName = dispName;
            dev.headerLine = ['---------------------- ',dev.devPrintName,' ----------------------'];  

            idnResponse = dev.queryCommand('*IDN?');
            disp(dev.headerLine)
            % Verify device
            disp(['Instrument Connected : ',idnResponse ]);
            if contains(idnResponse, 'Coherent', 'IgnoreCase',true)
                disp('Coherent IQ transmitter successfully connected')
            else
                dev.closeDevice();
                error('Failed to connect to Coherent IQ transmitter')
            end

            if strcmpi(printMode, 'on')
                dev.printMode = 1;
            else
                dev.printMode = 0;
            end

            dev.findLimits();
        end

        %% Set limits
        function dev = setPowerSafetyLimits(dev, value)
            % Sets software limit for power
            arguments
                dev
                value {mustBeNumeric, mustBeNonnegative}
            end
            dev.checkPowerDevLimits(value);
            dev.powerSafetyLimits = value;
        end
        
        %% Wavelength
        % check the unit
        function setWavelength_nm(dev, channel, wavelength)
            % Set the wavelength in nm
            arguments
            dev
            channel {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(channel, 1)}
            wavelength double {mustBeNumeric, mustBePositive}
            end
            % wavelength = wavelength*1e-9;
            % If wavelength is outside device limits, set to the closest limit
            if (wavelength < dev.wavelengthDevLimits(channel, 1))
                wavelength = dev.wavelengthDevLimits(channel, 1);
                disp(['Wavelength set to ',num2str(wavelength),' nm. Maximum wavelength is ',num2str(dev.wavelengthDevLimits(channel, 1)),' nm'])
            elseif (wavelength > dev.wavelengthDevLimits(channel, 2))
                wavelength = dev.wavelengthDevLimits(channel, 2);
                disp(['Wavelength set to ',num2str(wavelength),' nm. Minimum wavelength is ',num2str(dev.wavelengthDevLimits(channel, 2)),' nm'])
            end
            dev.writeCommand(['SOUR:CHAN', num2str(channel), ':WAV ', num2str(wavelength)]); % format wavelength
        end
        
        function value = getSetWavelength_nm(dev, channel)
            % Get the set wavelength in pm
            arguments
                dev
                channel {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(channel, 1)}
            end
            value = str2double(dev.queryCommand(['SOUR:CHAN', num2str(channel), ':WAV? SET']));
            if dev.printMode
                dev.printMiniHeader(['Wavelength set to ', num2str(value), ' nm'])
            end
        end

        %% Bias
        function setAutoBiasON(dev, modulator)
            % Turn on auto bias for all modulators
            arguments
                dev
                modulator char {mustBeMember(modulator, ['XI', 'XQ', 'XP'])}
            end
            dev.writeCommand(['ABC:',modulator,':PILOT ON']);
            if dev.printMode
                dev.printMiniHeader(['Turning on auto bias for ', modulator])
            end
        end
        
        function value = checkAutoBias(dev, modulator)
            % Check if auto bias is on for all modulators
            arguments
                dev
                modulator char {mustBeMember(modulator, ['XI', 'XQ', 'XP'])}
            end
            value = dev.queryCommand(['ABC:',modulator,':PILOT?']);
            if dev.printMode
                dev.printMiniHeader(['Auto bias for ',modulator,' is ', value])
            end
        end
        
        function setAutoBiasOFF(dev, modulator)
            % Turn off auto bias for all modulators
            arguments
                dev
                modulator char {mustBeMember(modulator, ['XI', 'XQ', 'XP'])}
            end
            dev.writeCommand(['ABC:',modulator,':PILOT OFF']);
            if dev.printMode
                dev.printMiniHeader(['Turning off auto bias for ', modulator])
            end
        end
        
        function calibrateBias(dev)
            % Calibrate the bias for all modulators
            dev.writeCommand('ABC:CALIBRATE');
            if dev.printMode
                dev.printMiniHeader('Auto bias calibration completed')
            end
        end

        %% Power
        function setPower_dBm(dev, channel, power)
            % add _dBm to variable name 
            % Set the power in dBm
            arguments
                dev
                channel {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(channel, 1)}
                power double {mustBeNumeric}
            end
            dev.checkPowerLimits(dev, power)
            dev.writeCommand(['SOUR:CHAN', num2str(channel), ':POW ', num2str(power)]);
        end
        
        function value = getSetPower_dBm(dev, channel)
            % Get the set power in dBm
            arguments
                dev
                channel {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(channel, 1)}
            end
            value = str2double(dev.queryCommand(['SOUR:CHAN', num2str(channel), ':POW? SET']));
            if dev.printMode
                dev.printMiniHeader(['Power set to ', num2str(value), ' dBm'])
            end
        end

        function value = getActualPower_dBm(dev, channel)
            % Get the acutal power in dBm
            arguments
                dev
                channel {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(channel, 1)}
            end
            value = str2double(dev.queryCommand(['SOUR:CHAN', num2str(channel), ':POW? ACT']));
            dev.printMiniHeader(['Actual power is ', num2str(value), ' dBm'])
        end
        
        function value = getModulatedOutputPower_dBm(dev)
            % Get the measured power in dBm
            value = pow2db(str2double(dev.queryCommand('ABC:PDP?')));
            dev.printMiniHeader(['Measured power is ', num2str(value), ' dBm'])
        end

        %% On/Off
        function powerON(dev, channel)
            % Turn on the laser
            arguments
                dev
                channel {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(channel, 1)}
            end
            dev.writeCommand(['OUTP:CHAN', num2str(channel), ':STATE ON']);
        end
        
        function powerOFF(dev, channel)
            % Turn off the laser
            arguments
                dev
                channel {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(channel, 1)}
            end
            dev.writeCommand(['OUTP:CHAN', num2str(channel), ':STATE OFF']);
        end
        
        function value = checkPowerState(dev, channel)
            % Check the power status of the laser
            arguments
                dev
                channel {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(channel, 1)}
            end
            value = dev.queryCommand(['OUTP:CHAN', num2str(channel), ':STATE?']);
            if dev.printMode
                % dev.printMiniHeader();
                dev.printMiniHeader(['Power status is ', value])
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
        
        function output = queryCommand(dev,inputText)
            % Query command to the instrument. Uses QueryString() function from VISA_Instrument class
            output = dev.devHandle.QueryString(inputText);
        end
    end

    methods (Access = private)
        %% Limits
        function dev = findLimits(dev)
            % Get the power device limits
            dev.powerDevLimits(1) = str2double(dev.queryCommand('SOUR:CHAN1:POW? MIN'));
            dev.powerDevLimits(2) = str2double(dev.queryCommand('SOUR:CHAN1:POW? MAX'));

            dev.powerSafetyLimits = dev.powerDevLimits;
            % Get the wavelength device limits
            dev.wavelengthDevLimits(1) = str2double(dev.queryCommand('SOUR:CHAN1:WAV? MIN'));
            dev.wavelengthDevLimits(2) = str2double(dev.queryCommand('SOUR:CHAN1:WAV? MAX'));
        end

        function checkPowerLimits(dev, val)
            % Checks input power against safety limits defined by the user
            if(val > dev.powerSafetyLimits(2) || val < dev.powerSafetyLimits(1))
                error("%s: Power %.3f dBm outside safety limits set by user", dev.devPrintName, val)
            end
        end

        function checkPowerDevLimits(dev, val)
            % Checks input power against the device safety limits
            if(val > dev.powerDevLimits(2) || val < dev.powerDevLimits(1))
                error("%s: Power %.3f dBm outside device safety limits", dev.devPrintName, val)
            end
        end

        %% Print 
        function printMiniHeader(dev, text)
            disp(strcat('Log from ## ',dev.devPrintName,' @ ',string(datetime('now')),' :'));
            disp(text);
        end
    end
end