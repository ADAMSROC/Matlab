function [data, experimentInfo] = adamsPreprocess(filename, varargin)

%% ADAMS preprocess code
% This is an all-purpose preprocessing function to format data from the
% experimental setup in the ADAMS lab. All four files should be in the same
% folder during runtime.

% This function takes in any of the following file types:
%       - .nev
%       - .ns2
%       - .ns5
%       - .mat (the files that are saved to the exData folder in the control computer)

% It then builds up the other three filenames from the same experiment and
% compiles the information into two structures.

%   Data 
%       - t-by-1 structure where t is the number of trials (defined by STIM_ON and STIM_OFF codes)

%   experimentInfo
%       - structure containing information that doesn't change across
%         trials

% Optional Name, Value pairs:
%       - 'preStimDataLength'        default: 0.5s
%       - 'postStimDataLength'       default: 0s
%       - 'eyeResampleRate'          default: 1000Hz
%       - 'wholeTrialEEG'            default: false

% filename = 'rolo_2019.May.17.11.43.51_ganCycle.mat';
% filename = 'Ro20190517_s37e_ganCycle_0001.ns2';

%% Input Parser
%%%%%%%%%%%%%%%%%%%%%%% Default Values %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
defaultPreStimDataLength = 0.5; % in seconds
defaultPostStimDataLength = 0;  % in seconds
defaultEyeResampleRate = 1000;  % in Hz
defaultWholeTrialEEG = 0;

%%%%%%%%%%%%%%%%%%%%%%% Parser %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addRequired(p, 'filename')
addParameter(p, 'preStimDataLength',defaultPreStimDataLength)
addParameter(p,'postStimDataLength',defaultPostStimDataLength)
addParameter(p, 'eyeResampleRate', defaultEyeResampleRate)
addParameter(p, 'wholeTrialEEG', defaultWholeTrialEEG)
parse(p, filename, varargin{:})
%%%%%%%%%%%%%%%%%%%%%%% Deconstruct Parser %%%%%%%%%%%%%%%%%%%%%%%%%%%%
filename = p.Results.filename;
preStimDataLength = p.Results.preStimDataLength;
postStimDataLength = p.Results.postStimDataLength;
eyeResampleRate = double(p.Results.eyeResampleRate);
wholeTrialEEG = logical(double(p.Results.wholeTrialEEG));
directory = fileparts(which(filename));
if isempty(directory)
    error('adamsPreprocess: File not found, make sure it is in your path')
end
cd(directory)

%% Helper functions

% This is just so date formats can be ubiquitous. More OCD than necessary

    function [date, year, mon, day, theTime] = formatDate(input)
        % helper function for adamsPreprocess
        allMonths = {'Jan';'Feb';'Mar';'Apr';'May';'Jun';'Jul';'Aug';'Sep';'Oct';'Nov';'Dec'};
        if isstring(input)||iscell(input)
            input = string(input);
            year = char(input(1));
            month = char(input(2));
            day = char(input(3));
            hour = char(input(4));
            minute = char(input(5));
            second = char(input(6));
            mon = find(ismember(allMonths, month));
            if mon <= 9
                mon = ['0', char(mon)];
            else
                mon = char(mon);
            end
        elseif ischar(input)
            year = input(1:4);
            mon = input(5:6);
            day = input(7:8);
            month = allMonths{str2num(mon)};
        else
            error('formatDate: Invalid Input type. Must be string or character array')
        end
        date = [month, ' ',day, ',', ' ', year];
        if isstring(input)||iscell(input)
           theTime = [hour, ':', minute, ':', second];
           date = [date, ' ', theTime];
        else
            theTime = [];
        end
    end



%% Parse filename

if size(strfind(filename, '.'),2)~=1
    fileType = split(filename, '.');
    fileType = ['.', char(fileType(end))];
    [~,fileRoot] = strtok(fliplr(filename),'.');
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
            warning('Subject Name not in code, add a case (line 91)')
    end
    fileParts = split(fileRoot, '_');
    xml = [char(fileParts(3)) '.xml'];
    date = char(fileParts(1));
    date = date(3:end); % remove subject name part
    [date, yr, mon, dae, theTime] = formatDate(date);
    session = char(fileParts(2));
    subSession = char(fileParts(end));
    allCodesFile = dir(eval(sprintf('fullfile(pwd, ''*%s*.mat'')', [lower(subject), '_', yr, '.', date(1:3), '.', dae,'.'])));
    %allCodesFile = [allCodesFile.folder,filesep, allCodesFile.name];
    allCodesFile = allCodesFile.name;
elseif contains(fileType, 'mat') && size(strfind(filename, '.'),2)==6
    [subject, remain] = strtok(fileRoot, '_');
    [date, remain] = strtok(remain,'_');
    xml = [remain(2:end) '.xml'];
    date = split(date, '.');
    [date, yr, mon, dae, theTime] = formatDate(date);
    session = input('Session (eg. ''s37e''):  ');
    subSession = input('subSession (eg. ''0001''):  ');
    allCodesFile = filename;
else
    error('adamsPreprocess: Unrecognized file type: %s', fileType)
end

experimentInfo.subject = subject;
experimentInfo.xml = xml;
experimentInfo.date = date;

%% load appropriate files

dataRoot = [subject(1:2), yr, mon,dae, '_',session, '_' xml(1:end-4), '_', subSession];
nevFile = [dataRoot, '.nev']; assert(isfile(nevFile), 'adamsPreprocess: NEV file not found in path');
ns2File = [dataRoot, '.ns2']; assert(isfile(ns2File), 'adamsPreprocess: NS2 file not found in path');
ns5File = [dataRoot, '.ns5']; if ~isfile(ns5File); hasNS5 = false; warning('adamsPreprocess: NS5 file not found in path'); ns5File=[]; disp(['Press any Key to Continue' newline]); pause; else; hasNS5 = true; end
experimentInfo.dataSources = {allCodesFile; nevFile; ns2File; ns5File};

nev = readNEV_withDigIn(nevFile);
ns2 = read_nsx(ns2File);
if hasNS5
    ns5 = read_nsx(ns5File);
end
allCodes = load(allCodesFile);
experimentInfo.behav = allCodes.behav;
allCodes = allCodes.allCodes;
samplingRate = double(ns2.hdr.Fs);
experimentInfo.params = codes2params(nev);


%% Decode files

[fileEvents, fileTimes] = exDecode(nev);
trialStartTimes = fileTimes(ismember(fileEvents,{'START_TRIAL'}));
trialEndTimes = fileTimes(ismember(fileEvents,{'END_TRIAL'}));
stimOnTimes = fileTimes(ismember(fileEvents,{'STIM_ON'}));
stimOffTimes = fileTimes(ismember(fileEvents,{'STIM_OFF'}));

% this ensures that codes are only counted once and that the trials all
% line up
[x, y] = meshgrid(stimOnTimes, stimOffTimes);
z = y-x;
z(z<0)=inf;
[ts, rows] = min(z);
stimOffTimes = stimOffTimes(rows);
[x, y] = meshgrid(stimOnTimes, trialStartTimes);
z = x-y;
z(z<0)=inf;
[ts, rows] = min(z);
trialStartTimes = trialStartTimes(rows);
[x, y] = meshgrid(trialStartTimes, trialEndTimes);
z = y-x;
z(z<0)=inf;
[ts, rows] = min(z);
trialEndTimes = trialEndTimes(rows);

% Throw out last trial if runex ended mid trial
if rows(end)==1
    trialStartTimes = trialStartTimes(1:end-1);
    trialEndTimes = trialEndTimes(1:end-1);
    stimOnTimes = stimOnTimes(1:end-1);
    stimOffTimes = stimOffTimes(1:end-1);
end

startIndx = find(ismember(fileTimes, trialStartTimes));
endIndx = find(ismember(fileTimes, trialEndTimes));

%% Epoch the EEG data

stimOnSamples = nevMsec2nsxSample(stimOnTimes,double(ns2.hdr.Fs), 0, 30000) - round(samplingRate*preStimDataLength);
stimOffSamples = nevMsec2nsxSample(stimOffTimes,double(ns2.hdr.Fs), 0, 30000) + round(samplingRate*postStimDataLength);
trialStartSamples = nevMsec2nsxSample(trialStartTimes,double(ns5.hdr.Fs), 0, 30000);
trialEndSamples =  nevMsec2nsxSample(trialEndTimes,double(ns5.hdr.Fs), 0, 30000);
trialStartSamplesEEG = nevMsec2nsxSample(trialStartTimes,samplingRate, 0, 30000);
trialEndSamplesEEG =  nevMsec2nsxSample(trialEndTimes,samplingRate, 0, 30000);

nTrials = size(stimOnSamples,1);
eegEpochs = cell(nTrials,1);
if ~wholeTrialEEG
    for samp = 1:nTrials
        events{samp} = fileEvents(startIndx(samp):endIndx(samp));
        eventTimes{samp} = fileTimes(startIndx(samp):endIndx(samp))-fileTimes(startIndx(samp));
        eegEpochs{samp,1} = ns2.data(:,stimOnSamples(samp):stimOffSamples(samp))';
    end
else
    for samp = 1:nTrials
        eegEpochs{samp,1} = ns2.data(:,trialStartSamplesEEG(samp):trialEndSamplesEEG(samp))';
    end
end

%% Spike Times


%% Saccade Data

rawEye = cell(nTrials,1);
eyePosition = cell(nTrials,1);
if hasNS5
    for samp = 1:nTrials
        rawEye{samp,1} = ns5.data(1:2,trialStartSamples(samp):trialEndSamples(samp));
        rawEye{samp,1} = resample(rawEye{samp,1}', eyeResampleRate, double(ns5.hdr.Fs));
        pupilDiam{samp,1} = ns5.data(3,trialStartSamples(samp):trialEndSamples(samp));
        pupilDiam{samp,1} = resample(pupilDiam{samp,1}', eyeResampleRate, double(ns5.hdr.Fs));
%         eyePosition{samp,1} = eye2deg(rawEye{samp}, experimentInfo.params);
%         eyePosition{samp} = resample(eyePosition{samp,1}', eyeResampleRate, double(ns5.hdr.Fs));
    end
    wrapper = @(x) eye2deg(x',experimentInfo.params)';
    eyePosition = cellfun(wrapper, rawEye, 'UniformOutput', false);
end



%% Combine trial data into single structure

fieldNames = {'events', 'eventTimes', 'EEG', 'eyeXY'};
fieldVals = [events', eventTimes', eegEpochs, eyePosition];
data = cell2struct(fieldVals,fieldNames,2);



end
