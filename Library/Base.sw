% this spec is implicitly imported by every user-defined spec

spec

  import Base/String     % imported by System       imports Char, List       
  import Base/Char       % imported by String       imports Integer          
  import Base/List       % imported by String       imports Integer, Option
  import Base/Option     % imported by List         imports Compare
  import Base/Integer    % imported by List, Char   imports Nat, Compare, Functions
  import Base/Nat        % imported by Integer
  import Base/Compare    % imported by Integer
  import Base/Functions  % imported by Integer
  import Base/System     %                          imports String, List, Option

endspec
