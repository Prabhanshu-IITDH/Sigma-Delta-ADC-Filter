% gen_input.m - Generate 1-bit Delta-Sigma Stream for Verilog Simulation
clear; clc;

% --- Parameters ---
Fs_target = 1000;          % Target Output Sample Rate (e.g., 1 kHz)
Decimation_Total = 128;    % Total Decimation (64 * 1 * 2)
Fs_in = Fs_target * Decimation_Total; % Input Sample Rate (128 kHz)

N_out_samples = 32768;      % Desired number of output samples for FFT
N_in_samples = N_out_samples * Decimation_Total; % Total input bits needed

% --- Generate Analog Sine Wave ---
t = (0:N_in_samples-1) / Fs_in;
f_sig = 30;                % Signal Frequency (30 Hz) - must be < Fs_target/2
amp = 0.5;                 % Amplitude (0.8 of full scale to avoid saturation)
u = amp * sin(2*pi*f_sig*t);

% --- Delta-Sigma Modulation (2nd Order Software Model) ---
% Converts floating point sine wave to 1-bit stream
q = zeros(1, N_in_samples);
int1 = 0; int2 = 0;        % Integrator states

disp('Generating bitstream...');
for i = 1:N_in_samples
    % Input to first integrator (Feedback is q[i-1])
    if i > 1
        feedback = q(i-1);
    else
        feedback = 0;
    end
    
    % 2nd Order Modulator Loop
    diff1 = u(i) - feedback;
    int1 = int1 + diff1;
    diff2 = int1 - feedback;
    int2 = int2 + diff2;
    
    % Quantizer (Comparator)
    if int2 >= 0
        q(i) = 1;
    else
        q(i) = -1; % Internally -1, but we write 0 to file
    end
end

% --- Save to File ---
% Map -1 to 0 for Verilog (Verilog reads 0/1)
q_verilog = (q > 0); 

fid = fopen('input_stream.txt', 'w');
fprintf(fid, '%d\n', q_verilog);
fclose(fid);

fprintf('File input_stream.txt generated with %d bits.\n', N_in_samples);
fprintf('Run your Verilog simulation now!\n');