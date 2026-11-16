classdef LecroyRx < handle
    %QP-IQRx Class to control Quantifi Photonics IQ Receiver
    properties
        devHandle
        devPrintName
        printMode
        headerLine
    end
    
    properties (GetAccess = public, SetAccess = private)
        % Properties that can be accessed by external functions
        wavelengthDevLimits =  [1527.6 1565.4];
        frequencyDevLimits
        powerDevLimits = [6 16.1];
        powerSafetyLimits
    end

    properties (Access = private)
        channels
    end

    methods
        %% Constructor
        function dev = LecroyRx(dsoHandle, dispName, printMode)
            arguments
                dsoHandle {mustBeA(dsoHandle, 'Lecroy_DSO')}
                dispName char = 'Lecroy Receiver'
                printMode char {mustBeMember(printMode, ['on', 'off', 'ON', 'OFF', 'On', 'Off'])} = 'on'
            end
            try
                dev.devHandle = dsoHandle;
            catch ME
                error ('Error initializing %s:\n%s', dispName, ME.message);
            end

            dev.channels = 1;
            
            dev.devPrintName = dispName;
            dev.headerLine = ['---------------------- ',dev.devPrintName,' ----------------------'];
            
            idnResponse = dev.queryCommand('*IDN?');
            disp(dev.headerLine)
            % Verify device
            disp(['Instrument Connected : ',idnResponse ]);
            if contains(idnResponse, 'Lecroy', 'IgnoreCase',true)
                disp('Laser Receiver successfully connected')
            else
                dev.closeDevice();
                error('Failed to connect to Laser Receiver through DSO');
            end
            
            if strcmpi(printMode, 'on')
                dev.printMode = 1;
            else
                dev.printMode = 0;
            end

            dev.findLimits();
        end
        %% Destructor
        function closeDevice(dev)
            % Close the device connection
            dev.devHandle.closeDevice();
        end
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
                dev.printMiniHeader(['Frequency set to ', num2str(frequency), ' THz'])
            end
        end

        function response = getSetFrequency(dev, channel)
            % Get the current laser frequency
            response = dev.queryCommand('VBS? return=app.OMA.LaserFrequency');
            if dev.printMode
                dev.printMiniHeader(['Current Laser Frequency: ', num2str(response), ' THz']);
            end
        end
        %% Wavelength
        function setWavelength_nm(dev, channel, wavelength)
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
                dev.printMiniHeader(['Wavelength set to ', num2str(wavelength*1e-9), ' nm'])
            end
        end
        function response = getSetWavelength_nm(dev, channel)
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
                dev.printMiniHeader(['Power set to ', num2str(power), ' dBm'])
            end
        end

        function response = getSetPower_dBm(dev, channel)
            % Get the current laser power
            response = str2double(dev.queryCommand('VBS? return=app.OMA.LaserPower'));
            if dev.printMode
                dev.printMiniHeader(['Current Laser Power: ', num2str(response), ' dBm']);
            end
        end

        function value = getActualPower_dBm(dev, channel)
            % Get the acutal power in dBm
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
            end
            value = str2double(dev.queryCommand('VBS? return=app.OMA.LaserPower'));
            dev.printMiniHeader(['Actual power is ', num2str(value), ' dBm'])
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

        %% Write/Query Commands
        function writeCommand(dev, command)
            % Write a command to the device
            dev.devHandle.writeCommand(command);
        end

        function response = queryCommand(dev, command)
            % Query a command from the device
            response = dev.devHandle.queryCommand(command);
        end
    end

    methods (Access = private)
        %% Limits
        function dev = findLimits(dev)
            % Find the device limits
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
        
        %% Print
        function printMiniHeader(dev, text)
            disp(strcat('Log from ## ',dev.devPrintName,' @ ',string(datetime('now')),' :'));
            disp(text);
        end
    end
end
