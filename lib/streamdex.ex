defmodule Streamdex do
  @moduledoc """
  Documentation for `Streamdex`.
  """

  alias Streamdex.Devices



  def devices do
    HID.enumerate()
    |> Enum.filter(fn hid ->
      hid.vendor_id == @vendor_id and
        hid.product_id in Map.keys(@products)
    end)
    |> Enum.map(fn hid ->
      module = @products[hid.product_id]
      module.new(hid)
    end)
  end

  def start(device) do
    device.module.start(device)
  end
end
