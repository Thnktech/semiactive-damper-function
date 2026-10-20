function [pub, priv] = list_vehicles()
%LIST_VEHICLES Names of the public vehicles and of the private ones present.
%   [pub, priv] = LIST_VEHICLES() returns cell arrays of vehicle names.
%   priv lists only private vehicles whose files exist in this clone (D21).

pub = {'sedan_ref', 'small_car', 'suv', 'light_van'};
privDir = fullfile(fileparts(mfilename('fullpath')), 'private');
candidates = {'erod_front', 'erod_rear'};
priv = candidates(cellfun(@(n) isfile(fullfile(privDir, [n '.m'])), candidates));
end
