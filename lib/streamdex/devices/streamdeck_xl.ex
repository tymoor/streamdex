defmodule Streamdex.Devices.StreamdeckXl do
  alias Streamdex.Devices

  import Bitwise
  require Logger

  @config %{
    name: "Stream Deck XL",
    keys: %{
      count: 32,
      cols: 8,
      rows: 4,
      pixel_width: 120,
      pixel_height: 120,
      image_format: :jpeg,
      flip: {false, false},
      rotation: 0
    },
      blank_mfa: {Devices.Blanks, :plus, []}
    }
  }

  defstruct(
    vendor_id: 0x0FD9,
    product_id: 0x006C,
    hid: nil,
    hid_info: nil,
    config: @config,
    module: __MODULE__
    )

  def new(hid_device) do
    %__MODULE__{hid_info: hid_device}
  end

  def start(d) do
    {:ok, device} = open(d.hid_info)
    d = %{d | hid: device}
    reset_key_stream(d)
    reset(d)
    d
  end

  def stop(d) do
    HID.close(d.hid)
  end

  def open(hid_device) do
    HID.open(hid_device.path)
  end

  def read(d, size) do
    HID.read(d.hid, size)
  end

  def poll(d) do
    case read_key_states(d) do
      "" -> nil
      <<_::8, result::binary>> -> parse_result(result)
    end
  end

  def read_feature(d, report_id, size) do
    HID.read_report(d.hid, report_id, size)
  end

  def write(d, payload, log_as \\ nil) do
    HID.write(d.hid, payload)
  end

  def write_feature(d, payload, log_as \\ nil) do
    result = HID.write_report(d.hid, payload)
  end

  def read_key_states(d) do
    # First byte should be report ID and can be dropped
    {:ok, binary} = read(d, 14)
    binary
  end

  def reset_key_stream(d) do
    payload = rightpad_bytes(0x02, d.config.image.report.length)

    {:ok, _} = write(d, payload, "reset key stream")
  end

  def reset(d) do
    payload = rightpad_bytes(<<0x03, 0x02>>, 32)

    {:ok, _} = write_feature(d, payload, "reset")
  end

  def set_brightness(d, percent) when is_float(percent) do
    set_brightness(d, trunc(percent * 100))
  end

  def set_brightness(d, percent) when is_integer(percent) do
    percent = min(max(percent, 0), 100)
    payload = rightpad_bytes(<<0x03, 0x08, percent>>, 32)
    write_feature(d, payload)
  end

  def set_key_image(d, key_index, binary) do
    send_key_image_chunk(d, binary, key_index, 0)
  end

  def to_key_image(binary) do
    {:ok, image} = Image.from_binary(binary)

    new_binary =
      image
      |> Image.thumbnail!(@config.keys.pixel_width, fit: :fill, height: @config.keys.pixel_height)
      |> Image.write!(:memory, suffix: ".jpg", quality: 100)

    new_binary
  end

  defp send_key_image_chunk(_, <<>>, _, _), do: :ok

  defp send_key_image_chunk(d, binary, key_index, page_number) do
    bytes_remaining = byte_size(binary)
    payload_length = @config.image.report.payload_length
    length = min(bytes_remaining, payload_length)

    {bytes, remainder, is_last} =
      case binary do
        <<bytes::binary-size(payload_length), remainder::binary>> ->
          {bytes, remainder, 0}

        bytes ->
          {bytes, <<>>, 1}
      end

    header = <<
      0x02,
      0x07,
      key_index &&& 0xFF,
      is_last,
      length::size(16)-unsigned-integer-little,
      page_number::size(16)-unsigned-integer-little
    >>

    8 = byte_size(header)

    payload = header <> bytes

    payload = rightpad_bytes(payload, @config.image.report.length)

    1024 = byte_size(payload)

    case write(d, payload, "set key image chunk") do
      {:ok, _} ->
        send_key_image_chunk(d, remainder, key_index, page_number + 1)

      err ->
        err
    end
  end

  defp rightpad_bytes(other, to_size) when not is_binary(other) do
    rightpad_bytes(<<other>>, to_size)
  end

  defp rightpad_bytes(binary, to_size) do
    if byte_size(binary) >= to_size do
      binary
    else
      size = byte_size(binary)
      remainder = to_size - size
      binary <> <<0::size(remainder * 8)>>
    end
  end

  @button_down 1
  @button_up 0
  defp button_state(state) do
    case state do
      @button_down -> :down
      @button_up -> :up
    end
  end

  @button_count @config.keys.cols * @config.keys.rows
  defp parse_result(<<0, 8, 0, buttons::binary-size(@button_count), _::binary>>) do
    states =
      buttons
      |> :binary.bin_to_list()
      |> Enum.map(&button_state/1)

    %{
      part: :keys,
      event: :button,
      states: states
    }
  end

  defp parse_result(result) do
    Logger.warn("Unhandled result: #{inspect(result)}")
    nil
  end
end
