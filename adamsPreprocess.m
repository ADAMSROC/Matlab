function [data, experimentInfo] = adamsPreprocess(filename)
% This is an all-purpose preprocessing function to format data from the
% experimental setup in the ADAMS lab.

% This function takes in any of the following file types:
%       - .nev
%       - .ns2
%       - .ns5
%       - .mat (the files that are saved to the exData folder in the control computer)


%% Helper functions

    function [date, year, mon, day] = formatDate(input)
        % helper function for adamsPreprocess
        if isstring(input)
            year = char(input(1));
            mon = char(input(2));
            day = char(input(3));
            hour = char(input(4));
            minute = char(input(5));
            second = char(input(6));
        elseif ischar(input)
            year = input(1:4);
            mon = input(5:6);
            day = input(7:8);
        else
            error('formatDate: Invalid Input type. Must be string or character array')
        end

        switch mon
            case {'01', 'Jan'}
                month = 'January';
            case {'02', 'Feb'}
                month = 'February';
            case {'03', 'Mar'}
                month = 'March';
            case {'04', 'Apr'}
                month = 'April';
            case {'05', 'May'}
                month = 'May';
            case {'06', 'Jun'}
                month = 'June';
            case {'07', 'Jul'}
                month = 'July';
            case {'08', 'Aug'}
                month = 'August';
            case {'09', 'Sep'}
                month = 'September';
            case {'10', 'Oct'}
                month = 'October';
            case {'11','Nov'}
                month = 'November';
            case {'12','Dec'}
                month = 'December';
        end
        date = [month, ' ',day, ',', ' ', year];
        if isstring(input)
           date = [date, ' ', hour, ':', minute, ':', second];
        end
    end



%% Parse filename


if size(strfind(filename, '.'),2)~=1
    fileType = split(filename, '.');
    fileType = ['.', char(fileType(end))];
    [~,fileRoot] = strtok(fliplr(filename2),'.');
    fileRoot = fliplr(fileRoot(2:end));
else
    [fileRoot, fileType] = strtok(filename, '.');
end
    
if contains(fileType, 'nev')||contains(fileType, 'ns2')||contains(fileType, 'ns5')
    switch fileRoot(1:2)
        case 'Ro'
            subject = 'Rolo';
        case 'Tw'
            subject = 'Twizzler';
        case 'Sk'
            subject = 'Skittles';
        otherwise
            subject = input('Subject Name: ');
    end
    fileParts = split(fileRoot, '_');
    xml = [char(fileParts(3)) '.xml'];
    date = char(fileParts(1));
    date = date(3:end); % remove subject name part
    [date, yr, mon, dae] = formatDate(date);
    session = char(fileParts(2));
    subSession = char(fileParts(end));
elseif contains(fileType, 'mat') && size(strfind(filename, '.'),2)==6
    [subject, remain] = strtok(fileRoot, '_');
    [date, remain] = strtok(remain,'_');
    xml = [remain(2:end) '.xml'];
    date = split(date, '.');
    [date, yr, mon, dae] = formatDate(date);
    session = input('Session: (eg. ''s37e'')');
    subSession = input('subSession (eg. ''0001''): ');
else
    error('adamsPreprocess: Unrecognized file type: %s', fileType)
end

experimentInfo.subject = subject;
experimentInfo.xml = xml;
experimentInfo.date = date;

%% load appropriate files

dataRoot = [subject(1:2), yr, mon,dae, '_',session, '_' xml(1:end-4), '_', subSession];
nevFile = [dataRoot, '.nev'];
ns2File = [dataRoot, '.ns2'];

nev = readNEV_withDigIn(nevFile);
ns2 = read_nsx(ns2)




end
