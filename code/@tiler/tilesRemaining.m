function n=tilesRemaining(obj)
	% Return the number of tiles remaining in this section
	%
	% function n=tilesRemaining
	%
	n=[];
	if isempty(obj.positionArray)
		error('No position array. No acquisition running.')
		return
	end

	n = isnan(obj.positionArray(:,end));
	n = sum(n);
