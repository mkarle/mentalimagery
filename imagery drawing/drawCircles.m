function [ centers ] = drawCircles( BW, I, E )
%DRAWCIRCLES Summary of this function goes here
%   Detailed explanation goes here

s = regionprops(BW, 'centroid', 'eccentricity', 'Perimeter');
figure;
imagesc(ones(size(I)));
centers = reshape([s(:).Centroid]', [2,size(s,1)]);
centers = centers';
perims= reshape([s(:).Perimeter],size(s));
radii = perims / 2 /pi;
radii(radii <= 30) = 0;
viscircles(centers, radii, 'EdgeColor', 'b');
end

