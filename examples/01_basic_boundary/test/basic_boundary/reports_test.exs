defmodule BasicBoundary.ReportsTest do
  use ExUnit.Case, async: true

  alias BasicBoundary.Reports

  test "creating and fetching a post through the domain's exported interface works" do
    post = Reports.create_and_fetch("Hello", "World")

    assert post.title == "Hello"
    assert post.body == "World"
  end
end
