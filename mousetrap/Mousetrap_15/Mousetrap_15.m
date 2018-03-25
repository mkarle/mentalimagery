%%%AUTHOR: MARK KARLE
clear all
I = imread('ReverseMousetrap_15.png');
[M, N,O] = size(I);
portcullisLocation = [1541 1031 30 144];
mouseLocation = [1394 1019 123 156];
%% SEPARATE GROUPS OF OBJECTS
%%%%%%
%find the blue objects (movable)
blueBW = createBlueMask(I);
%close small gaps
blueBW = imclose(blueBW,strel('disk',8));
%fill holes to find intersection with greens or yellows
blueBW = imfill(blueBW, 'holes');
blueCC = bwconncomp(blueBW);

%blueObjects contains a binary image of each object so they can move
%independently
blueObjects = zeros( blueCC.ImageSize(1),blueCC.ImageSize(2), blueCC.NumObjects);
object = zeros(blueCC.ImageSize(1),blueCC.ImageSize(2));
for i= 1:blueCC.NumObjects
    object(:,:) = 0;
    object(blueCC.PixelIdxList{i}) = 1;
    blueObjects(:,:,i) = object;
end
blueObjects = logical(blueObjects);

%black  - no need to separate since they do not move
blackBW = createBlackMask(I);
blackBW = imclose(blackBW, strel('disk', 8));

%yellow - no need to separate since they do not move
yellowBW = createYellowMask(I);
yellowBW = imdilate(yellowBW, strel('disk', 8));

%green - separate because they move independently
greenBW = createGreenMask(I);
greenBW = imdilate(greenBW, strel('disk', 8));
greenCC = bwconncomp(greenBW);
greenObjects = zeros( greenCC.ImageSize(1),greenCC.ImageSize(2), greenCC.NumObjects);
object = zeros(greenCC.ImageSize(1),greenCC.ImageSize(2));
for i = 1: greenCC.NumObjects
    object(:,:) = 0;
    if(size(greenCC.PixelIdxList{i},1) > 700)
        object(greenCC.PixelIdxList{i}) = 1;
        greenObjects(:,:,i) = object;
    end
end
greenObjects = logical(greenObjects);
%get rid of empty green objects
greenCount = 0;
tmpGreen = 0;
greenBW = zeros(M,N);
for i = 1:greenCC.NumObjects
    if any(any(greenObjects(:,:,i)))
        greenCount = greenCount + 1;
        tmpGreen(1:M,1:N, greenCount) = greenObjects(:,:,i);
        greenBW = greenBW | tmpGreen(1:M,1:N,greenCount);
    end
end
greenObjects = tmpGreen;

attachmentPointsCC = bwconncomp(greenBW & blueBW);
attachmentPoints = zeros( attachmentPointsCC.ImageSize(1),attachmentPointsCC.ImageSize(2), attachmentPointsCC.NumObjects);
object = zeros(attachmentPointsCC.ImageSize(1),attachmentPointsCC.ImageSize(2));
for i = 1: attachmentPointsCC.NumObjects
    object(:,:) = 0;
    object(attachmentPointsCC.PixelIdxList{i}) = 1;
    attachmentPoints(:,:,i) = object;
end
attachmentPoints = logical(attachmentPoints);
clear tmpGreen; 
greenBW = zeros(M,N);
for i = 1 : attachmentPointsCC.NumObjects
    greenBW = greenBW | attachmentPoints(:,:,i);
end
%% find centers of mass:
blueCOM = regionprops(blueObjects, 'centroid');
blueCOM = cat(1, blueCOM.Centroid);
blueCOM = round(blueCOM(:,1:2));

yellowCOM = regionprops(yellowBW, 'centroid');
yellowCOM = cat(1, yellowCOM.Centroid);
yellowCOM = round(yellowCOM(:,1:2));


greenCOM = regionprops(attachmentPoints, 'centroid');
greenCOM = cat(1, greenCOM.Centroid);
greenCOM = round(greenCOM(:,1:2));
%% find centers of rotation
% there is a precedence for rotation points:
% if there is an intersection with yellow, use yellow's COM
% if there is an intersection with green, use green's COM
% otherwise use blue's COM

blueCOR = zeros(blueCC.NumObjects, 2); 
%blueIsFixed is 1 if blue is fixed by a yellow point, 0 otherwise
blueIsFixed = zeros(1, blueCC.NumObjects);
%attachmentMap maps each blue object to its attachment point
attachmentMap = blueIsFixed;
for i = 1:blueCC.NumObjects
    for n = 1:size(yellowCOM,1)
        if(blueObjects(yellowCOM(n,2), yellowCOM(n,1), i))
            blueCOR(i, :) = yellowCOM(n, :);
            blueIsFixed(i) = 1;
        end
    end

     for n = 1:size(greenCOM,1)
        if blueObjects(greenCOM(n,2), greenCOM(n,1), i)
            if ~blueCOR(i,:)
                blueCOR(i,:) = greenCOM(n,:);
            end
            attachmentMap(i) = n;
        end
    end
    if ~blueCOR(i, :)
        blueCOR(i, :) = blueCOM(i, :);
    end
end


%% find real images corresponding to the binary images
movableObjects = zeros(M,N,3,blueCC.NumObjects);

for i = 1 : blueCC.NumObjects
    movableObjects(:,:,:,i) = (bsxfun(@times, I, cast(blueObjects(:,:,i), 'like',I)));
end
movableObjects = uint8(movableObjects);
%% movement loops
mouseSaved = false;

for x= 1:150
   objectWasPulled = zeros(1,blueCC.NumObjects); 
%fixed rotators
for i = 1 : blueCC.NumObjects
    if blueIsFixed(i)
        %rotate in the direction with the greater area
        left = regionprops(blueObjects(:,1:blueCOR(i,1),i),'area','centroid');
        right = regionprops(blueObjects(:,blueCOR(i,1):end,i),'area','centroid');
        leftArea  = left.Area;
        rightArea = right.Area;
        %check if another object is on top
        for n = 1 : blueCC.NumObjects
            if n ~= i && any(any(blueObjects(:,:,n) & blueObjects(:,:,i))) && blueCOM(i, 2) > blueCOM(n,2)
                %add the area of the other to this object
                nleftArea = regionprops(blueObjects(:,1:blueCOR(i,1),n),'area');
                nrightArea = regionprops(blueObjects(:,blueCOR(i,1):end,n),'area');
                if size(nleftArea) > 0
                    leftArea = leftArea + nleftArea.Area;
                end
                if size(nrightArea) > 0
                    rightArea = rightArea + nrightArea.Area;
                end
            end
        end
        %if one area is greater by a threshold, rotate it
        difference = leftArea - rightArea;
        if abs(difference) > 3000
            
            blueBW = blueBW - blueObjects(:,:,i);
            if ~(blackBW & blueObjects(:,:,i))
                blueObjects(:,:,i) = rotateAround(blueObjects(:,:,i), blueCOR(i,2), blueCOR(i,1),...
                    (difference / abs(difference)) * 10);
                %if it is attached, pull the string
                if(attachmentMap(i) ~= 0)
                    greenBW = greenBW - attachmentPoints(:,:,attachmentMap(i));
                    attachmentPoints(:,:,attachmentMap(i)) = rotateAround(attachmentPoints(:,:,attachmentMap(i)), blueCOR(i,2), blueCOR(i,1),...
                    (difference / abs(difference)) * 10);
                    greenBW = greenBW | attachmentPoints(:,:,attachmentMap(i));
                end
            end
            blueBW = blueBW | blueObjects(:,:,i);
        end
    end
end

%string pulls
difference = 0;
for i = 1 : blueCC.NumObjects
    if(attachmentMap(i) ~= 0)
        tmpAttachmentPoints = regionprops(attachmentPoints, 'centroid');
        tmpAttachmentPoints = cat(1, tmpAttachmentPoints.Centroid);
        tmpAttachmentPoints = round(tmpAttachmentPoints(:,1:2));
        %if pulled the string, draw a new line and lift the other COM
        if tmpAttachmentPoints(attachmentMap(i), :) ~= greenCOM(attachmentMap(i),:)
            oldDistance = sqrt((greenCOM(attachmentMap(i),1) - greenCOM(attachmentMap(4),1)) * ...
                (greenCOM(attachmentMap(i),1) - greenCOM(attachmentMap(4),1)) + ...
                (greenCOM(attachmentMap(i),2) - greenCOM(attachmentMap(4),2)) * ...
                (greenCOM(attachmentMap(i),2) - greenCOM(attachmentMap(4),2)));
            newDistance = sqrt((tmpAttachmentPoints(attachmentMap(i),1) - greenCOM(attachmentMap(4),1)) * ...
                (tmpAttachmentPoints(attachmentMap(i),1) - greenCOM(attachmentMap(4),1)) + ...
                (tmpAttachmentPoints(attachmentMap(i),2) - greenCOM(attachmentMap(4),2)) * ...
                (tmpAttachmentPoints(attachmentMap(i),2) - greenCOM(attachmentMap(4),2)));
            difference = abs(oldDistance - newDistance);
            greenCOM = tmpAttachmentPoints;
            %can't figure out any way except ad hoc to inform the other
            %object
            objectWasPulled(4) = 1;
        end
        
        %if string was pulled on this object, lift the object and draw a
        %new line
        if(objectWasPulled(i))
            greenBW = greenBW - attachmentPoints(:,:,attachmentMap(i));
            attachmentPoints(:,:,i) = imtranslate(attachmentPoints(:,:,attachmentMap(i)), [0, -difference]);
            greenBW = greenBW | attachmentPoints(:,:,attachmentMap(i));
            
            blueBW = blueBW - blueObjects(:,:,i);
            blueObjects(:,:,i) = imtranslate(blueObjects(:,:,i), [0, - difference]);
            blue = blueBW | blueObjects(:,:,i);
            
            greenCOM = regionprops(attachmentPoints, 'centroid');
            greenCOM = cat(1, greenCOM.Centroid);
            greenCOM = round(greenCOM(:,1:2));
        end
    end
end

%gravity falls
for i = 1:blueCC.NumObjects
    if ~blueIsFixed(i) && ~objectWasPulled(i)
        if ~((blackBW & blueObjects(:,:,i)) | (blueObjects(:,:,i) & blueObjects(:,:,2)))
            blueObjects(:,:,i) = imtranslate(blueObjects(:,:,i), [0 10]);
        end

    end
end
blueBW = zeros(M,N);
for i = 1:blueCC.NumObjects
    blueBW = blueBW | blueObjects(:,:,i);
end

imshow(imfuse(I,blueBW))
%imwrite(imfuse(I,blueBW), strcat( num2str(x), '.png'));

%check if mouse can escape
if all(all(blueBW(portcullisLocation(2) : portcullisLocation(2) + portcullisLocation(4), portcullisLocation(1) : portcullisLocation(1) + portcullisLocation(3)) == 0));
    mouseSaved = true;
end
if mouseSaved
    break;
end

if any(any(blueBW(mouseLocation(2) : mouseLocation(2) + mouseLocation(4), mouseLocation(1) : mouseLocation(1) + mouseLocation(3))))
    'Mouse is hit!'
    break;
end

end

if mouseSaved
    'Mouse Saved!'
else
    'Mouse not saved'
end
