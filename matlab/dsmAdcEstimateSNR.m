function [SNR, ENOB] = dsmAdcEstimateSNR(bitStream, OSR)
%DSMADCESTIMATESNR Estimate SNR from DSM bitstream
% ROBUST VERSION: Forces all vectors to columns to prevent memory crashes.

    % 1. Force Input to Column Vector
    bitStream = bitStream(:); 
    N = numel(bitStream);
    
    % 2. Calculate Window and Force to Column
    w = ds_hann(N);
    w = w(:); % <--- THIS FIXES THE 122GB ERROR
    
    % 3. FFT (Element-wise multiply is now guaranteed safe)
    spec = fft(bitStream .* w) / (N/4);
    
    % 4. Identify Signal Peak (Search DC to Nyquist)
    half_bin = floor(N/2);
    [~,fi] = max(abs(spec(1:half_bin))); 
    fin = fi-1; 
    
    % 5. Calculate SNR using Toolbox
    fB = ceil(N/(2*OSR));
    if fB < 1, fB = 1; end
    
    % Ensure bandwidth covers the signal
    if fin > fB
        warning('Signal peak is outside the OSR bandwidth! Check OSR or Input Frequency.');
    end
    
    SNR = calculateSNR(spec(1:fB), fin);
    
    % 6. ENOB
    ENOB = (SNR - 1.76)/6.02;
end