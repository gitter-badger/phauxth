defmodule Phauxth.ConfirmTest do
  use Phauxth.TestCase
  use Plug.Test

  alias Phauxth.{TestRepo, TestUser, UserHelper}

  @valid_link "email=fred%2B1%40mail.com&key=lg8UXGNMpb5LUGEDm62PrwW8c20qZmIw"
  @invalid_link "email=wrong%40mail.com&key=lg8UXGNMpb5LUGEDm62PrwW8c20qZmIw"
  @incomplete_link "email=wrong%40mail.com"

  setup do
    UserHelper.add_user()
    :ok
  end

  def call_confirm(link, opts) do
    conn(:get, "/confirm?" <> link)
    |> fetch_query_params
    |> Phauxth.Confirm.call(opts)
  end

  def user_confirmed do
    user = TestRepo.get_by(TestUser, email: "fred+1@mail.com")
    user.confirmed_at
  end

  test "init function" do
    assert Phauxth.Confirm.init([]) == {:email, "email", 60}
  end

  test "confirmation succeeds for valid token" do
    conn = call_confirm(@valid_link, {:email, "email", 60})
    assert user_confirmed()
    assert conn.private.phauxth_user
  end

  test "confirmation fails for invalid token" do
    conn = call_confirm(@invalid_link, {:email, "email", 60})
    refute user_confirmed()
    assert conn.private.phauxth_error =~ "Invalid credentials"
  end

  test "confirmation fails for expired token" do
    conn = call_confirm(@valid_link, {:email, "email", 0})
    refute user_confirmed()
    assert conn.private.phauxth_error =~ "Invalid credentials"
  end

  test "invalid link error" do
    conn = call_confirm(@incomplete_link, {:email, "email", 60})
    refute user_confirmed()
    assert conn.private.phauxth_error =~ "Invalid credentials"
  end

  test "confirmation fails for already confirmed account" do
    call_confirm(@valid_link, {:email, "email", 60})
    conn = call_confirm(@valid_link, {:email, "email", 60})
    assert user_confirmed()
    assert conn.private.phauxth_error =~ "Invalid credentials"
  end

  test "confirmation succeeds with custom identifier" do
    phone_link = "phone=55555555555&key=lg8UXGNMpb5LUGEDm62PrwW8c20qZmIw"
    conn = call_confirm(phone_link, {:phone, "phone", 60})
    assert user_confirmed()
    assert conn.private.phauxth_user
  end

  test "gen_token_link" do
    {key, link} = Phauxth.Confirm.gen_token_link("fred@mail.com")
    assert link =~ "email=fred%40mail.com&key="
    assert :binary.match(link, [key]) == {26, 32}
  end

  test "gen_token_link with custom unique_id" do
    {key, link} = Phauxth.Confirm.gen_token_link("55555555555", :phone)
    assert link =~ "phone=55555555555&key="
    assert :binary.match(link, [key]) == {22, 32}
  end

end
