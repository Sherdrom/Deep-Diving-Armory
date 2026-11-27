using System.Buffers.Binary;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace DDA.AmmoLoading;

public sealed partial class DeepAmmoLoader
{
    private const int SnapshotPageSize = 128;
    private const int MaxSnapshotPages = 16384;
    private const int MaxSnapshotBytes = SnapshotPageSize * MaxSnapshotPages;
    private sealed record Snapshot(uint Revision, IReadOnlyDictionary<string, int> Stock, SupplyPool[]? Supplies = null, bool SupplyError = false);

    // Keep collectible plugin types out of the process-wide reflection serializer cache.
    [JsonSerializable(typeof(Snapshot))]
    [JsonSerializable(typeof(BatchResult))]
    private sealed partial class LoaderJson : JsonSerializerContext;

    private string EncodeSnapshot()
    {
        var snapshot = new Snapshot(revision, Stock.Counts, supplies, supplyError);
        byte[] json = JsonSerializer.SerializeToUtf8Bytes(snapshot, LoaderJson.Default.Snapshot);
        if (json.Length is > SnapshotPageSize and <= MaxSnapshotBytes)
        {
            // Use a fast quality setting and only compress if Base64 still reduces the payload.
            var buffer = new byte[json.Length * 3 / 4];
            if (BrotliEncoder.TryCompress(json, buffer.AsSpan(sizeof(int)), out int written, quality: 1, window: 16) &&
                1 + 4 * ((written + sizeof(int) + 2) / 3) < json.Length)
            {
                BinaryPrimitives.WriteInt32LittleEndian(buffer, json.Length);
                return "~" + Convert.ToBase64String(buffer, 0, written + sizeof(int));
            }
        }
        return Encoding.UTF8.GetString(json);
    }

    private static Snapshot? DecodeSnapshot(string data)
    {
        try
        {
            if (!data.StartsWith('~')) { return JsonSerializer.Deserialize(data, LoaderJson.Default.Snapshot); }
            byte[] compressed = Convert.FromBase64String(data[1..]);
            if (compressed.Length <= sizeof(int)) { return null; }
            int length = BinaryPrimitives.ReadInt32LittleEndian(compressed);
            if (length is < 1 or > MaxSnapshotBytes) { return null; }
            var json = new byte[length];
            return BrotliDecoder.TryDecompress(compressed.AsSpan(sizeof(int)), json, out int written) && written == length
                ? JsonSerializer.Deserialize(json, LoaderJson.Default.Snapshot) : null;
        }
        catch (Exception e) when (e is FormatException or JsonException) { return null; }
    }
}
