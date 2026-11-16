classdef QP_IQRx < handle
    %QP-IQRx Class to control Quantifi Photonics IQ Receiver
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

    properties (Access = private)
        channels
        slotNo
    end

    methods
        %% Constructor
        function dev = QP_IQRx(IPAddress, slotNo, dispName, printMode)
            arguments
                IPAddress char
                slotNo {mustBeNumeric} = 1
                dispName char = 'QP IQ Receiver'
                printMode char {mustBeMember(printMode, ['on', 'off', 'ON', 'OFF', 'On', 'Off'])} = 'on'
            end
            try
                dev.devHandle = VISA_Instrument(['TCPIP::', IPAddress,'::INSTR']);
            catch ME
                error ('Error initializing %s:\n%s', dispName, ME.message);
            end
            
            dev.slotNo = slotNo;
            dev.channels = 1;
            
            dev.devPrintName = dispName;
            dev.headerLine = ['---------------------- ',dev.devPrintName,' ----------------------'];
            
            idnResponse = dev.queryCommand('*IDN?');
            disp(dev.headerLine)
            % Verify device
            disp(['Instrument Connected : ',idnResponse ]);
            if contains(idnResponse, 'Quantifi Photonics', 'IgnoreCase',true)
                disp('Quantifi Photonics Laser successfully connected')
            else
                dev.closeDevice();
                error('Failed to connect to Quantifi Photonics Laser')
            end
            
            if strcmpi(printMode, 'on')
                dev.printMode = 1;
            else
                dev.printMode = 0;
            end
            
            dev.findLimits();
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
            catch ME
                error('Error setting power safety limits:\n%s', ME.message);
            end
        end
        
        %% Power
        function setPower_dBm(dev, channel, power)
                    % Set the power in dBm
                    arguments
                        dev
                        channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
                        power double {mustBeNumeric}
                    end
            dev.checkPowerLimits(channel, power)
            dev.writeCommand(['SOUR',num2str(dev.slotNo), ':CHAN', num2str(channel), ':POW ', num2str(power)]);
        end
        
        function value = getSetPower_dBm(dev, channel)
            % Get the set power in dBm
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
            end
            value = str2double(dev.queryCommand(['SOUR',num2str(dev.slotNo), ':CHAN', num2str(channel), ':POW? SET']));
            if dev.printMode
                dev.printMiniHeader(['Power set to ', num2str(value), ' dBm'])
            end
        end
        
        function value = getActualPower_dBm(dev, channel)
            % Get the acutal power in dBm
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
            end
            value = str2double(dev.queryCommand(['SOUR',num2str(dev.slotNo), ':CHAN', num2str(channel), ':POW? ACT']));
            dev.printMiniHeader(['Actual power is ', num2str(value), ' dBm'])
        end
               
        %% Wavelength
        function setWavelength_nm(dev, channel, wavelength)
            % Set the wavelength in nm
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
                wavelength double {mustBeNumeric, mustBePositive}
            end
            wavelength = wavelength*1e-9;
            % If wavelength is outside device limits, set to the closest limit
            if (wavelength < dev.wavelengthDevLimits(channel, 1))
                wavelength = dev.wavelengthDevLimits(channel, 1);
                disp(['Wavelength set to ',num2str(wavelength),' nm. Maximum wavelength is ',num2str(dev.wavelengthDevLimits(channel, 1)),' nm'])
            elseif (wavelength > dev.wavelengthDevLimits(channel, 2))
                wavelength = dev.wavelengthDevLimits(channel, 2);
                disp(['Wavelength set to ',num2str(wavelength),' nm. Minimum wavelength is ',num2str(dev.wavelengthDevLimits(channel, 2)),' nm'])
            end
            dev.writeCommand(['SOUR',num2str(dev.slotNo), ':CHAN', num2str(channel), ':WAV ', num2str(wavelength*1e-9)]);        % format wavelength
        end
        
        function value = getSetWavelength_nm(dev, channel)
            % Get the set wavelength in nm
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
            end
            value = str2double(dev.queryCommand(['SOUR',num2str(dev.slotNo), ':CHAN', num2str(channel), ':WAV? SET']))*1e9;
            if dev.printMode
                dev.printMiniHeader(['Wavelength set to ', num2str(value), ' nm'])
            end
        end
        
        function value = getActualWavelength_nm(dev, channel)
            % Get the acutal wavelength in nm
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
            end
            value = str2double(dev.queryCommand(['SOUR',num2str(dev.slotNo), ':CHAN', num2str(channel), ':WAV? ACT']))*1e9;
            dev.printMiniHeader(['Actual wavelength is ', num2str(value), ' nm'])
        end
        
        %% On/Off
        function powerON(dev, channel)
            % Turn on the power
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
            end
            dev.writeCommand(['OUTP',num2str(dev.slotNo), ':CHAN', num2str(channel), ':STATE ON']);
            pause(30)
        end
        
        function powerOFF(dev, channel)
            % Turn off the power
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
            end
            dev.writeCommand(['OUTP',num2str(dev.slotNo), ':CHAN', num2str(channel), ':STATE OFF']);
        end
        
        function value = checkPowerState(dev, channel)
            % Check the power state
            arguments
                dev
                channel {mustBeNumeric, mustBeLessThanOrEqual(channel, 1), mustBePositive}
            end
            value = dev.queryCommand(['OUTP',num2str(dev.slotNo), ':CHAN', num2str(channel), ':STATE?']);
            if dev.printMode
                dev.printMiniHeader(['Power state is ', value])
            end
        end
        
        %% Measurement
        function value  = getReceiverPower_dBm(dev)
            % Get the measured power in dBm
            arguments
                dev
            end
            value = str2double(dev.queryCommand(['SENS',num2str(dev.slotNo), ':SIG? ACT']));
            dev.printMiniHeader(['Received power is ', num2str(value), ' dBm'])
        end

        %% Staus
        function value = checkProgramStatus(dev)
            % Check the status of the device
            value = dev.queryCommand(['SLOT', num2str(dev.slotNo), ':OPC?']);
        end
        
        function value = checkError(dev)
            % Check the Event Status Register of the device for error messages
            value = dev.queryCommand('*ESR?');
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
        
        %% Print
        function printMiniHeader(dev, text)
            disp(strcat('Log from ## ',dev.devPrintName,' @ ',string(datetime('now')),' :'));
            disp(text);
        end
    end
end