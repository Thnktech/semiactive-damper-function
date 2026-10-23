function T = write_vehicle_overview()
%WRITE_VEHICLE_OVERVIEW Write results/vehicles/vehicle_overview.csv (public vehicles only, D21).
%   T = WRITE_VEHICLE_OVERVIEW() returns the table it wrote.

pub = list_vehicles();   % public vehicles only; private data must not be written to results
rows = cell(numel(pub), 1);
for k = 1:numel(pub)
    V = get_vehicle(pub{k});
    [fb, fw] = natural_frequencies(V);
    c_crit = 2*sqrt(V.ks*V.ms);
    rows{k} = {V.name, V.label, V.ms, V.mu, V.ks, V.kt, V.c_min, V.c_passive, V.c_max, ...
        V.c_passive/c_crit, fb, fw};
end
T = cell2table(vertcat(rows{:}), 'VariableNames', {'vehicle', 'label', 'ms_kg', 'mu_kg', ...
    'ks_N_per_m', 'kt_N_per_m', 'c_min_Ns_per_m', 'c_passive_Ns_per_m', 'c_max_Ns_per_m', ...
    'zeta_passive', 'f_body_Hz', 'f_wheel_Hz'});

root = project_root();
outDir = fullfile(root, 'results', 'vehicles');
if ~isfolder(outDir), mkdir(outDir); end
writetable(T, fullfile(outDir, 'vehicle_overview.csv'));
end
