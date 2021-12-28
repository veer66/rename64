defmodule Rename64 do
  @moduledoc """
  Documentation for `Rename64`.
  """

  def extract_q(name_list_path) do
    name_list_path
      |> Path.basename
      |> (fn p -> Regex.named_captures(~r/Namelist_(?<q>Q\d+)\.txt/, p) end).()
     |> (fn m -> m["q"] end).()
  end

  def chunk([], chunks) do
    Enum.map(chunks, fn chunk -> Enum.reverse(chunk) end)
      |> Enum.reverse
      |> Enum.filter(fn chunk -> chunk != [] end)
  end

  def chunk([line | rest], chunks) do
    cond do
      String.match?(line, ~r/^\s*$/) ->
        chunk(rest, [[] | chunks])
      chunks == [] ->
        chunk(rest, [[line]])
      length(chunks) > 1  ->
        [this_chunk | rest_chunks] = chunks
        chunk(rest, [[line | this_chunk] | rest_chunks])
      length(chunks) == 1  ->
        [this_chunk] = chunks
        chunk(rest, [[line | this_chunk]])
    end
  end
  
  def chunk(lines) do
    chunk(lines, [])
  end

  def parse_chunk(chunk) do
    [q, names] = chunk
    [q, Regex.split(~r/\s*,\s*/, names)]
  end
  
  def parse_name_list(content) do
    content
      |> (fn c -> Regex.split(~r/\r?\n/, c) end).()
      |> chunk
      |> Enum.map(fn chunk -> parse_chunk(chunk) end)
  end

  def copy_files(source_dir, output_dir, q, names) do
    tgt_dir = Path.join(output_dir, q)
    IO.puts "Q: #{q}"
    File.mkdir_p(tgt_dir)
    Enum.each(Path.wildcard(Path.join([source_dir, "#{q}.*"])),
      fn src_path -> Enum.each(names, fn name ->
        ext = Regex.named_captures(~r/(?<ext>\.[A-Za-z]+)$/, src_path)["ext"]
        tgt_path = Path.join([tgt_dir, "#{name}#{ext}"])
        File.copy(src_path, tgt_path)
      end)
    end)

  end
  
  def rename_each_q(source_dir, output_dir) do
    IO.puts "SOURCE DIR #{source_dir}"
    name_list_path = Path.wildcard(Path.join([source_dir, "Namelist_*.txt"])) |> List.first
    case File.read(name_list_path) do
      {:ok, content} ->
        Enum.each(parse_name_list(content),
          fn [q, names] -> copy_files(source_dir, output_dir, q, names) end)
      _ -> IO.puts "Cannot convert #{source_dir}"
    end
  end

  def rename(source_dir, output_dir) do
    Enum.each(Path.wildcard(Path.join([source_dir, "Q*"])),
      fn sub_src_dir -> rename_each_q(sub_src_dir, output_dir) end)
  end
end
