function zbus_portal(cmdFile)
%ZBUS_PORTAL  Interactive program to form and modify the Z-bus of an N-bus power system.
%
%   Run:  >> zbus_portal                    (interactive)
%         >> zbus_portal('commands.txt')    (replay answers/commands from a file,
%                                            one per line - handy for large systems)
%
%   1. Insert the network: the N x N Z-bus matrix (element by element, as a
%      matrix expression, or loaded from a file), or branch data from which
%      the Z-bus is built.
%   2. The program waits for a command that changes the network topology.
%   3. It identifies the type of change (Type 1-4, branch removal, impedance
%      change, bus removal), modifies the Z-bus and displays the new matrix.
%
%   Commands can be chosen from the menu by number, or typed in one line:
%       add 2 5 0.1+0.3j      remove 1 2      change 3 4 0.2j      delbus 5
%   Bus 0 is the reference (ground) bus.  Impedances may be complex,
%   e.g. 0.25j, 0.02+0.08j, 1i*0.1.

addpath(fullfile(fileparts(mfilename('fullpath')), 'core'));   % Z-bus engine

if nargin < 1
    read_line('', {});                       % interactive: read the keyboard
else
    txt = fileread(cmdFile);
    lines = regexp(txt, '\r?\n', 'split');
    if ~isempty(lines) && isempty(lines{end}), lines(end) = []; end
    read_line('', lines, true);              % replay the file
end
try
    run_portal();
catch err
    if ~strcmp(err.identifier, 'zbus:eof'), rethrow(err); end
    fprintf('\n(end of command file)\n');
end
end

% ========================================================================
function run_portal()
print_banner();
S = setup_network();
zbus_show(S, 1, 'Initial Z-bus matrix');
print_menu();
history = {};

while true
    cmd = strtrim(read_line(sprintf('\nZbus> ')));
    if isempty(cmd), continue; end
    tok = regexp(cmd, '\s+', 'split');
    key = lower(tok{1});
    args = tok(2:end);
    old = S;
    changed = false;
    msg = '';
    try
        switch key
            case {'1', 'add'}
                v = get_args(args, {'  From bus p (0 = reference): ', ...
                    '  To bus q   (0 = reference): ', ...
                    '  Branch impedance Zb (e.g. 0.1+0.25j): '});
                [S, msg] = zbus_modify(S, 'add', v{:});
                changed = true;

            case {'2', 'remove', 'outage'}
                v = get_args(args(1:min(2, end)), {'  Bus p: ', '  Bus q (0 = reference): '});
                if numel(args) >= 3, v{3} = to_num(strjoin(args(3:end), ' ')); end
                [S, msg] = modify_asking_z(S, 'remove', v);
                changed = true;

            case {'3', 'change'}
                v = get_args(args, {'  Bus p: ', '  Bus q (0 = reference): ', ...
                    '  New impedance (Inf = open the branch): '});
                [S, msg] = modify_asking_z(S, 'change', v);
                changed = true;

            case {'4', 'delbus', 'removebus'}
                v = get_args(args, {'  Bus to remove: '});
                [S, msg] = zbus_modify(S, 'delbus', v{1});
                changed = true;

            case {'5', 'show', 'z'}
                zbus_show(S, 1, 'Present Z-bus matrix');

            case {'6', 'branches', 'list'}
                zbus_branches(S);

            case {'7', 'verify', 'check'}
                zbus_verify(S);

            case {'8', 'undo'}
                if isempty(history)
                    fprintf('  Nothing to undo.\n');
                else
                    S = history{end};
                    history(end) = [];
                    zbus_show(S, 1, 'Z-bus after undo');
                end

            case {'9', 'save'}
                save_result(S);

            case {'h', 'help', '?', 'menu'}
                print_menu();

            case {'0', 'exit', 'quit', 'q'}
                zbus_show(S, 1, 'Final Z-bus matrix');
                fprintf('\nGoodbye.\n');
                return;

            otherwise
                fprintf('  Unknown command "%s". Type help to see the menu.\n', key);
        end
    catch err
        if strcmp(err.identifier, 'zbus:eof'), rethrow(err); end
        fprintf('  ERROR: %s\n', err.message);
        S = old;
        changed = false;
    end
    if changed
        history{end+1} = old; %#ok<AGROW>
        fprintf('\n  Change identified -> %s\n', msg);
        zbus_show(S, 1, 'Modified Z-bus matrix');
    end
end
end

% ========================================================================
function S = setup_network()
while true
    fprintf(['\nHow do you want to insert the network?\n' ...
        '   1. Enter the Z-bus matrix of an N-bus system\n' ...
        '   2. Enter branch (line) data and build the Z-bus\n' ...
        '   3. Use the built-in 4-bus example\n']);
    c = ask_value('Choice: ');
    try
        switch c
            case 1
                S = enter_matrix();
            case 2
                fprintf(['\nEnter the branch data as an m x 3 matrix [from to Zb] (0 = reference), e.g.\n' ...
                    '   [0 1 0.2j; 1 2 0.1j; 2 0 0.25j]     or     load(''lines.txt'')\n' ...
                    'or press Enter to type it branch by branch.\n']);
                B = read_branch_data(true);
                [S, steps] = zbus_build(B);
                print_steps(steps);
            case 3
                B = example_branches();
                fprintf('\nBuilt-in example (reactances in p.u.):\n');
                [S, steps] = zbus_build(B);
                zbus_branches(S);
                print_steps(steps);
            otherwise
                fprintf('  Please choose 1, 2 or 3.\n');
                continue;
        end
        return;
    catch err
        if strcmp(err.identifier, 'zbus:eof'), rethrow(err); end
        fprintf('  ERROR: %s\n  Please try again.\n', err.message);
    end
end
end

function S = enter_matrix()
N = ask_value('Number of buses N: ');
if N < 1 || N ~= round(N), error('zbus:args', 'N must be a positive integer.'); end
fprintf(['\nType the complete %d x %d matrix as an expression, e.g.  [0.2j 0.1j; 0.1j 0.3j]\n' ...
    'or  load(''zbus.txt'')  for a large system,  or press Enter to insert it element by element.\n'], N, N);
s = strtrim(read_line('Zbus = '));
if isempty(s)
    Z = zeros(N);
    fprintf('Insert the elements of the upper triangle (Z is symmetric: Z(j,i) = Z(i,j)).\n');
    for i = 1:N
        for j = i:N
            Z(i, j) = ask_value(sprintf('  Z(%d,%d) = ', i, j));
            Z(j, i) = Z(i, j);
        end
    end
else
    Z = eval(s);
end
if ~isequal(size(Z), [N N])
    error('zbus:args', 'The matrix is %dx%d, expected %dx%d.', size(Z, 1), size(Z, 2), N, N);
end
if max(abs(Z(:) - reshape(Z.', [], 1))) > 1e-9 * max(1, max(abs(Z(:))))
    fprintf('  Warning: the matrix is not symmetric; a Z-bus of a passive network should be.\n');
end
fprintf('Buses are numbered 1 to %d.\n', N);
S = struct('Z', Z, 'bus', 1:N, 'br', zeros(0, 3), 'topo', false);

fprintf(['\nOptional: enter the branch data [from to Zb] of this network so branches can be\n' ...
    'looked up by name and the result checked against inv(Ybus). Press Enter to skip.\n']);
B = read_branch_data(false);
if ~isempty(B)
    T = S; T.br = B; T.topo = true;
    if zbus_verify(T)
        S = T;
        fprintf('  Branch data accepted - topology tracking is on.\n');
    else
        fprintf('  The branch data does not reproduce this Z-bus - it was ignored.\n');
    end
end
end

function B = read_branch_data(allowManual)
s = strtrim(read_line('Branch data = '));
if isempty(s)
    B = zeros(0, 3);
    if ~allowManual, return; end
    m = ask_value('Number of branches: ');
    for r = 1:m
        fprintf(' Branch %d\n', r);
        B(r, 1) = ask_value('   From bus (0 = reference): ');
        B(r, 2) = ask_value('   To bus   (0 = reference): ');
        B(r, 3) = ask_value('   Impedance Zb: ');
    end
else
    B = eval(s);
end
if isempty(B), B = zeros(0, 3); return; end
if size(B, 2) ~= 3, error('zbus:args', 'Branch data must have 3 columns [from to Zb].'); end
ends = real(B(:, 1:2));
if any(ends(:) < 0) || any(ends(:) ~= round(ends(:)))
    error('zbus:args', 'Bus numbers must be non-negative integers (0 = reference).');
end
end

function B = example_branches()
%   from to  impedance (p.u.)
B = [ 0  1  0.20j
      0  4  0.25j
      1  2  0.10j
      1  3  0.15j
      2  3  0.20j
      3  4  0.10j
      2  4  0.25j ];
end

% ========================================================================
function [S, msg] = modify_asking_z(S, op, v)
% run a remove/change; if the branch impedance is unknown, ask for it
try
    [S, msg] = zbus_modify(S, op, v{:});
catch err
    if ~strcmp(err.identifier, 'zbus:needz'), rethrow(err); end
    fprintf('  %s\n', err.message);
    z = ask_value('  Present impedance of this branch: ');
    if strcmp(op, 'remove')
        [S, msg] = zbus_modify(S, 'remove', v{1}, v{2}, z);
    else
        [S, msg] = zbus_modify(S, 'change', v{1}, v{2}, v{3}, z);
    end
end
end

function v = get_args(args, prompts)
% take values from the typed command line, prompt for the missing ones
n = numel(prompts);
v = cell(1, n);
for i = 1:n
    if i < n && numel(args) >= i
        v{i} = to_num(args{i});
    elseif i == n && numel(args) >= n
        v{i} = to_num(strjoin(args(n:end), ' '));   % allow "0.1 + 0.2j"
    else
        v{i} = ask_value(prompts{i});
    end
end
end

function x = to_num(s)
x = str2num(s); %#ok<ST2NM>  (allows expressions such as 0.1+0.2j)
if ~isscalar(x)
    error('zbus:args', 'Could not read "%s" as a number.', s);
end
end

function x = ask_value(prompt)
while true
    s = strtrim(read_line(prompt));
    x = str2num(s); %#ok<ST2NM>
    if isscalar(x), return; end
    fprintf('  Please enter one number, e.g. 3, 0.25j or 0.1+0.3j\n');
end
end

function s = read_line(prompt, lines, fromFile)
% one line of user input: from the keyboard, or from the replayed command file
persistent queue useFile
if nargin >= 2                               % initialise
    queue = lines;
    useFile = nargin >= 3 && fromFile;
    s = '';
    return;
end
if ~useFile
    s = input(prompt, 's');
    return;
end
if isempty(queue)
    error('zbus:eof', 'End of command file.');
end
s = queue{1};
queue(1) = [];
fprintf('%s%s\n', prompt, s);                % echo, so the log reads like a session
end

function print_steps(steps)
fprintf('\nZ-bus building algorithm:\n');
for i = 1:numel(steps)
    fprintf('  %2d. %s\n', i, steps{i});
end
end

function save_result(S)
Zbus = S.Z; buses = S.bus; branches = S.br; %#ok<NASGU>
if exist('OCTAVE_VERSION', 'builtin')
    save('-mat7-binary', 'zbus_result.mat', 'Zbus', 'buses', 'branches');
else
    save('zbus_result.mat', 'Zbus', 'buses', 'branches');
end
fid = fopen('zbus_result.txt', 'w');
zbus_show(S, fid, 'Z-bus matrix');
zbus_branches(S, fid);
fclose(fid);
fprintf('  Saved zbus_result.mat and zbus_result.txt in %s\n', pwd);
end

function print_banner()
fprintf('\n==================================================================\n');
fprintf('   Z-BUS MATRIX PORTAL  -  modification of an N-bus power system\n');
fprintf('==================================================================\n');
end

function print_menu()
fprintf(['\nCommands (number or text; bus 0 = reference):\n' ...
    '   1  add p q Zb       add a branch / new bus  (Type 1-4 found automatically)\n' ...
    '   2  remove p q [Zb]  remove a branch (line outage)\n' ...
    '   3  change p q Znew  change the impedance of a branch\n' ...
    '   4  delbus k         remove bus k together with its branches\n' ...
    '   5  show             display the present Z-bus\n' ...
    '   6  branches         list the branches\n' ...
    '   7  verify           check Z-bus against inv(Ybus)\n' ...
    '   8  undo             undo the last change\n' ...
    '   9  save             save Z-bus to zbus_result.mat / .txt\n' ...
    '   0  exit\n']);
end
