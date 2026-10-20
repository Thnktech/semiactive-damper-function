function V = get_vehicle(name)
%GET_VEHICLE Load and validate a vehicle parameter struct (D13, D21).
%   V = GET_VEHICLE() loads the vehicle named in PROJECT_CONFIG.
%   V = GET_VEHICLE(name) loads the named vehicle.
%
%   Public vehicles live in this folder; private vehicles (D21) live in the
%   git-ignored subfolder private/. A private vehicle that is not present in
%   this clone raises 'vehicles:privateMissing'.
%
%   See also LIST_VEHICLES, PROJECT_CONFIG, NATURAL_FREQUENCIES.

if nargin < 1
    cfg = project_config();
    name = cfg.vehicle;
end
name = char(name);
[pub, priv] = list_vehicles();

if ismember(name, pub)
    V = feval(name);
elseif ismember(name, {'erod_front', 'erod_rear'})
    if ~ismember(name, priv)
        error('vehicles:privateMissing', ...
            ['Private vehicle ''%s'' is not available in this clone (D21). ' ...
             'Its data is kept local only.'], name);
    end
    V = feval(name);   % resolves to private/<name>.m from this folder
else
    error('vehicles:unknown', 'Unknown vehicle ''%s''. Available: %s.', ...
        name, strjoin([pub, priv], ', '));
end

validate_vehicle(V);
end

function validate_vehicle(V)
required = {'name', 'label', 'ms', 'mu', 'ks', 'kt', 'c_min', 'c_max', ...
    'c_passive', 'f_body_target', 'f_wheel_target', 'source'};
missing = setdiff(required, fieldnames(V));
if ~isempty(missing)
    error('vehicles:invalid', 'Vehicle ''%s'' lacks fields: %s.', V.name, strjoin(missing, ', '));
end
num = {'ms', 'mu', 'ks', 'kt', 'c_min', 'c_max', 'c_passive'};
for k = 1:numel(num)
    x = V.(num{k});
    if ~(isscalar(x) && isfinite(x) && x > 0)
        error('vehicles:invalid', 'Vehicle ''%s'': %s must be finite and > 0.', V.name, num{k});
    end
end
if ~(V.c_min < V.c_passive && V.c_passive < V.c_max)
    error('vehicles:invalid', 'Vehicle ''%s'': need c_min < c_passive < c_max.', V.name);
end
end
