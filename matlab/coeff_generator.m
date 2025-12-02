% gen_filters_final.m
% FIXED: No 'fdesign' error. Uses fir1/kaiser for max compatibility.
% FIXED: Correct Zero-Forcing logic (Odds have data, Evens are zero).
clear; clc;

% --- Parameters ---
N_taps_fir = 63;
N_taps_hb  = 31;
Word_W = 24;
Frac_W = 23;

% --- 1. Stronger FIR Compensation (Inverse Sinc) ---
fprintf('Designing FIR Compensation Filter...\n');
f = linspace(0, 1, 4096); 
R_cic = 64; N_cic = 3;
w = pi * f; 
% Calculate CIC response
cic_mag = abs((sin(w/2) ./ (R_cic * sin(w/(2*R_cic)))).^N_cic);
cic_mag(1) = 1; 
% Inverse Sinc
inv_sinc = 1 ./ cic_mag;
desired_mag = inv_sinc;
desired_mag(f > 0.25) = 0; 
b_fir = fir2(N_taps_fir-1, f, desired_mag); 
b_fir = b_fir / sum(b_fir); % Normalize gain

% --- 2. High-Attenuation Half-Band Filter (Manual Design) ---
fprintf('Designing Half-Band Filter (Kaiser Method)...\n');

% We use a Kaiser window with Beta=12. 
% This creates a filter with ~120dB stopband attenuation.
b_hb = fir1(N_taps_hb-1, 0.5, 'low', kaiser(N_taps_hb, 12));

% --- 3. The "Zero-Forcing" Logic (CRITICAL FIX) ---
% For a 31-tap filter, Center is at index 16.
% Halfband property: Ideally, every other coefficient is 0.
% In Matlab 1-based indexing:
%   - ODD indices (1, 3, 5...) contain the TAILS (Data).
%   - EVEN indices (2, 4... 14, 18...) contain the ZEROS.
%   - CENTER index (16) contains 0.5.

center_idx = 16;

% Step A: Force EVEN indices to zero (except center)
b_hb(2:2:end) = 0; 

% Step B: Force Center to exactly 0.5
b_hb(center_idx) = 0.5;

% Step C: Normalize remaining energy (ensure gain is exactly 1.0)
% (Optional, but good practice after forcing zeros)
% b_hb = b_hb / sum(b_hb); % Commented out to preserve 0.5 center exactly.

% --- 4. Split & Export ---
% hb_h0 gets ODD indices (1, 3, 5...). It contains the TAILS.
b_hb_h0 = b_hb(1:2:end); 

% hb_h1 gets EVEN indices (2, 4, 6...). It contains 0.5 and ZEROS.
b_hb_h1 = b_hb(2:2:end);

% Export
export_mem('fir_comp.mem', b_fir, Word_W, Frac_W);
export_mem('hb_h0.mem', b_hb_h0, Word_W, Frac_W);
export_mem('hb_h1.mem', b_hb_h1, Word_W, Frac_W);

fprintf('DONE. Files generated successfully.\n');
fprintf('Please check hb_h0.mem - it should contain non-zero data.\n');

function export_mem(filename, coeffs, width, frac)
    fid = fopen(filename, 'w');
    scale = 2^frac;
    for i = 1:length(coeffs)
        val_int = round(coeffs(i) * scale);
        max_val = 2^(width-1) - 1; min_val = -2^(width-1);
        if val_int > max_val, val_int = max_val; end
        if val_int < min_val, val_int = min_val; end
        if val_int < 0, val_int = val_int + 2^width; end
        fprintf(fid, '%s\n', dec2hex(val_int, width/4));
    end
    fclose(fid);
end