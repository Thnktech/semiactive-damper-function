function names = law_names()
%LAW_NAMES Control-law slots of controller.slx, read from the model (D24).
%   names = LAW_NAMES() returns a containers.Map from mode number to law name,
%   built from the subsystems Law_<n>_<Name> inside Control_law, e.g.
%   0 -> 'Passive', 1 -> 'Skyhook'. A law added later appears automatically.

% Read the names from the model instead of a fixed list: a new Law_<n>_ slot
% then appears in studies and plots without changing any script.
mdl = 'controller';
wasLoaded = bdIsLoaded(mdl);
load_system(mdl);
% Close the model again only if this function opened it (a model the user
% has open must stay open).
if ~wasLoaded
    c = onCleanup(@() close_system(mdl, 0));
end
b = find_system([mdl '/Control_law'], 'SearchDepth', 1, 'BlockType', 'SubSystem');
names = containers.Map('KeyType', 'double', 'ValueType', 'char');
for k = 1:numel(b)
    % Only subsystems named Law_<n>_<Name> are law slots; the number is the mode.
    tok = regexp(get_param(b{k}, 'Name'), '^Law_(\d+)_(\w+)$', 'tokens', 'once');
    if ~isempty(tok)
        names(str2double(tok{1})) = tok{2};
    end
end
end
