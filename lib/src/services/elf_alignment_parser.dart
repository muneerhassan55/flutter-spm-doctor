import 'dart:typed_data';

/// The minimum `p_align` value (in bytes) a `PT_LOAD` segment must declare
/// to be considered 16KB-page-size compliant.
const int kRequired16kbAlignment = 0x4000;

/// `p_type` value identifying a loadable program header segment.
const int _ptLoad = 1;

/// The result of inspecting a single ELF shared object (`.so`) file for
/// 16KB page-size alignment compliance.
class ElfAlignmentResult {
  /// Whether [bytes] passed to [ElfAlignmentParser.parse] was a valid ELF
  /// file. If `false`, all other fields are meaningless.
  final bool isValidElf;

  /// Whether the ELF file uses the 64-bit format (`ELFCLASS64`). `false`
  /// means 32-bit (`ELFCLASS32`).
  final bool is64Bit;

  /// The `p_align` value of every `PT_LOAD` segment found in the file.
  final List<int> loadSegmentAlignments;

  const ElfAlignmentResult({
    required this.isValidElf,
    required this.is64Bit,
    required this.loadSegmentAlignments,
  });

  /// An ELF file is 16KB-aligned when every `PT_LOAD` segment declares an
  /// alignment of at least [kRequired16kbAlignment]. A file with no
  /// `PT_LOAD` segments at all is treated as compliant (nothing to align).
  bool get isAligned =>
      isValidElf &&
      loadSegmentAlignments.every((a) => a >= kRequired16kbAlignment);

  static const invalid = ElfAlignmentResult(
    isValidElf: false,
    is64Bit: false,
    loadSegmentAlignments: [],
  );
}

/// Parses ELF program headers in pure Dart to check whether a native shared
/// object's `PT_LOAD` segments are aligned for Android's 16KB page-size
/// requirement, without shelling out to external tools.
class ElfAlignmentParser {
  /// Parses [bytes] as an ELF file and reports the alignment of every
  /// `PT_LOAD` program header segment. Returns [ElfAlignmentResult.invalid]
  /// if [bytes] isn't a recognizable ELF file.
  static ElfAlignmentResult parse(Uint8List bytes) {
    if (bytes.length < 20 ||
        bytes[0] != 0x7f ||
        bytes[1] != 0x45 /* E */ ||
        bytes[2] != 0x4c /* L */ ||
        bytes[3] != 0x46 /* F */ ) {
      return ElfAlignmentResult.invalid;
    }

    final eiClass = bytes[4]; // 1 = 32-bit, 2 = 64-bit
    final eiData = bytes[5]; // 1 = little-endian, 2 = big-endian
    final is64Bit = eiClass == 2;
    final endian = eiData == 2 ? Endian.big : Endian.little;

    if (eiClass != 1 && eiClass != 2) {
      return ElfAlignmentResult.invalid;
    }

    final data = ByteData.sublistView(bytes);

    int phoff, phentsize, phnum;
    try {
      if (is64Bit) {
        if (bytes.length < 64) return ElfAlignmentResult.invalid;
        phoff = data.getUint64(0x20, endian);
        phentsize = data.getUint16(0x36, endian);
        phnum = data.getUint16(0x38, endian);
      } else {
        if (bytes.length < 52) return ElfAlignmentResult.invalid;
        phoff = data.getUint32(0x1c, endian);
        phentsize = data.getUint16(0x2a, endian);
        phnum = data.getUint16(0x2c, endian);
      }
    } catch (_) {
      return ElfAlignmentResult.invalid;
    }

    final alignments = <int>[];

    for (var i = 0; i < phnum; i++) {
      final entryOffset = phoff + i * phentsize;
      if (entryOffset + phentsize > bytes.length) break;

      try {
        int pType, pAlign;
        if (is64Bit) {
          pType = data.getUint32(entryOffset, endian);
          pAlign = data.getUint64(entryOffset + 48, endian);
        } else {
          pType = data.getUint32(entryOffset, endian);
          pAlign = data.getUint32(entryOffset + 28, endian);
        }

        if (pType == _ptLoad) {
          alignments.add(pAlign);
        }
      } catch (_) {
        break;
      }
    }

    return ElfAlignmentResult(
      isValidElf: true,
      is64Bit: is64Bit,
      loadSegmentAlignments: alignments,
    );
  }
}
