function result = isord(obj)
import tilerUtils.yaml.*;
result = ~iscell(obj) && any(size(obj) > 1);
end
