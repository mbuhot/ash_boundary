defmodule AshBoundary.Test.Layers.Audit do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Accounts do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [AshBoundary.Test.Layers.Audit]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Notes do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [AshBoundary.Test.Layers.Accounts, AshBoundary.Test.Layers.Audit]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Workforce do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Layers.Notes,
      AshBoundary.Test.Layers.Accounts,
      AshBoundary.Test.Layers.Audit
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Platform do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Layers.Notes,
      AshBoundary.Test.Layers.Accounts,
      AshBoundary.Test.Layers.Audit
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Authorizations do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Layers.Workforce,
      AshBoundary.Test.Layers.Accounts,
      AshBoundary.Test.Layers.Audit
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.CaseManagement do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Layers.Authorizations,
      AshBoundary.Test.Layers.Platform,
      AshBoundary.Test.Layers.Accounts,
      AshBoundary.Test.Layers.Audit
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Communications do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Layers.Platform,
      AshBoundary.Test.Layers.Notes,
      AshBoundary.Test.Layers.Audit
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Insights do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Layers.CaseManagement,
      AshBoundary.Test.Layers.Notes,
      AshBoundary.Test.Layers.Audit
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Scheduling do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Layers.CaseManagement,
      AshBoundary.Test.Layers.Workforce,
      AshBoundary.Test.Layers.Accounts
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Billing do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Layers.Scheduling,
      AshBoundary.Test.Layers.Accounts,
      AshBoundary.Test.Layers.Audit
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Payroll do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Layers.Scheduling,
      AshBoundary.Test.Layers.Workforce,
      AshBoundary.Test.Layers.Audit
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.Evv do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Layers.Scheduling,
      AshBoundary.Test.Layers.Communications,
      AshBoundary.Test.Layers.Accounts
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Layers.FormBuilder do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [AshBoundary.Test.Layers.Communications, AshBoundary.Test.Layers.Notes]
  end

  resources do
  end
end
