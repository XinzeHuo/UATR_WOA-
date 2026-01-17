function write_bellhop_env_woa(envPath, ssp, H, bottom_type, src_z, rcv_z, r_vec)
% envPath: full path without extension
% ssp: struct with .z and .c
% H: water depth
% bottom_type: 'sand'|'mud'
% src_z: scalar
% rcv_z: vector
% r_vec: vector (meters)

envFile = [envPath '.env'];
fid = fopen(envFile, 'w');

fprintf(fid, '''WOA-based SSP: %s''\n', envPath);
fprintf(fid, '1000.00\n'); % frequency
fprintf(fid, '1\n');       % NMedia

% ---------------- SSP SECTION ----------------
fprintf(fid, '''CVW''   ! C-linear, Vacuum, dB/wavelength\n');
fprintf(fid, '%d  %.1f  %.1f\n', numel(ssp.z), 0.0, H);

for i=1:numel(ssp.z)
    fprintf(fid, '%8.2f  %8.2f  /\n', ssp.z(i), ssp.c(i));
end

% ---------------- SOURCES ----------------
fprintf(fid, '''R''  0.0\n');  % no offset
fprintf(fid, '%d\n', 1);       % NSD
fprintf(fid, '%8.2f /\n', src_z);

% ---------------- RECEIVERS ----------------
fprintf(fid, '%d\n', numel(rcv_z));  % NRD
fprintf(fid, ' ');
fprintf(fid, sprintf('%8.2f ', rcv_z));
fprintf(fid, '/\n');

% ---------------- RANGES ----------------
fprintf(fid, '%d\n', numel(r_vec)); % NR
fprintf(fid, ' ');
fprintf(fid, sprintf('%8.2f ', r_vec/1000)); % convert to km
fprintf(fid, '/\n');

% ---------------- BOTTOM ----------------
fprintf(fid, '''A''\n');        % Ray trace
fprintf(fid, '201  -30.0  30.0  /\n');
fprintf(fid, '0.0  150.0  1.5\n');

fclose(fid);
