defmodule Streamdex.Components.Key do
@moduledoc """
Represents a push-button 'Key' on a Stream Deck device.
"""

defstruct(

)

@type t :: %__MODULE__{

}

@callback key_position() :: {:ok, Integer.t, Integer.t} | {:error, String.t}

end
