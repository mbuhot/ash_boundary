defmodule Example.TestData do
  @moduledoc false

  @spec clear() :: :ok
  def clear do
    Enum.each(Example.Blog.list_posts!(), &Example.Blog.delete_post!/1)
    Enum.each(Example.Accounts.contributors!(), &Example.Accounts.remove_author!(&1.id))
  end
end
