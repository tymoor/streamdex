defmodule Streamdex.Devices.Device do
@moduledoc """
Defines the generic device behaviour for Stream Deck devices.
"""

defstruct(
  vendor_id: nil,
  device_id: nil
)

@type t :: %__MODULE__{
  vendor_id: Bitstring.t,
  device_id: Bitstring.t
}

@callback device_id() :: __MODULE__.t

@spec get_device(Bitstring.t, Bitstring.t) :: {:ok, any.t}, {:error, String.t}
def get_device(vendor_id, product_id) do
  #get the implemented Devices
  for d <- implemented_devices do
    d.
  end





  case {vendor_id, product_id} do
    {0x0FD9, 0x0084} -> {:ok, Devices.StreamdeckPlus}
    {0x0FD9, 0x0086} -> {:ok, Devices.StreamdeckPedal}
    {0x0FD9, 0x006C} -> {:ok, Devices.StreamdeckXl}
    _ -> {:error, "Device not recognized."}
  end
end

defp implemented_devices() do
  for {module, _} <- :code.all_loaded(),
    __MODULE__ in (module.module_info(:attributes)
                   |> Keyword.get_values(:behaviour)
                   |> List.flatten()) do
    module
  end
end



end
