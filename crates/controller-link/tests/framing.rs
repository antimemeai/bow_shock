use std::io::{self, Cursor, Read, Write};

use bow_shock_controller_link::{FrameReader, FrameWriter, MAX_FRAME_BYTES};

#[test]
fn records_preserve_exact_bytes_and_order() {
    let mut reader = FrameReader::new(Cursor::new(b"{\"id\":1}\n{\"text\":\"\\n\"}\n"));
    assert_eq!(reader.read_frame().unwrap(), Some(b"{\"id\":1}".to_vec()));
    assert_eq!(
        reader.read_frame().unwrap(),
        Some(b"{\"text\":\"\\n\"}".to_vec())
    );
    assert_eq!(reader.read_frame().unwrap(), None);
}

#[test]
fn payload_size_boundary_is_exact() {
    for size in [MAX_FRAME_BYTES - 1, MAX_FRAME_BYTES, MAX_FRAME_BYTES + 1] {
        let mut input = vec![b'x'; size];
        input.push(b'\n');
        let mut reader = FrameReader::new(Cursor::new(input));
        if size <= MAX_FRAME_BYTES {
            assert_eq!(reader.read_frame().unwrap(), Some(vec![b'x'; size]));
        } else {
            assert_eq!(
                reader.read_frame().unwrap_err().kind(),
                io::ErrorKind::InvalidData
            );
            assert_eq!(
                reader.read_frame().unwrap_err().kind(),
                io::ErrorKind::BrokenPipe
            );
        }
    }
}

#[test]
fn empty_and_corrupt_records_poison_the_reader() {
    for input in [b"\nvalid\n".as_slice(), b"a\rb\nvalid\n", b"\xff\nvalid\n"] {
        let mut reader = FrameReader::new(Cursor::new(input));
        assert_eq!(
            reader.read_frame().unwrap_err().kind(),
            io::ErrorKind::InvalidData
        );
        assert_eq!(
            reader.read_frame().unwrap_err().kind(),
            io::ErrorKind::BrokenPipe
        );
    }
}

#[test]
fn eof_between_frames_is_clean_but_inside_a_frame_is_truncation() {
    let mut clean = FrameReader::new(io::empty());
    assert_eq!(clean.read_frame().unwrap(), None);
    assert_eq!(clean.read_frame().unwrap(), None);
    let mut partial = FrameReader::new(Cursor::new(b"unterminated"));
    assert_eq!(
        partial.read_frame().unwrap_err().kind(),
        io::ErrorKind::UnexpectedEof
    );
    assert_eq!(
        partial.read_frame().unwrap_err().kind(),
        io::ErrorKind::BrokenPipe
    );
}

struct Fragmented {
    input: Cursor<Vec<u8>>,
    chunk: usize,
}

impl Read for Fragmented {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        let size = buf.len().min(self.chunk);
        self.input.read(&mut buf[..size])
    }
}

#[test]
fn fragmentation_including_split_utf8_preserves_frames() {
    for chunk in 1..=20 {
        let mut reader = FrameReader::new(Fragmented {
            input: Cursor::new("α🦅\nsecond\n".as_bytes().to_vec()),
            chunk,
        });
        assert_eq!(
            reader.read_frame().unwrap(),
            Some("α🦅".as_bytes().to_vec())
        );
        assert_eq!(reader.read_frame().unwrap(), Some(b"second".to_vec()));
        assert_eq!(reader.read_frame().unwrap(), None);
    }
}

struct InterruptedThenData {
    remaining_interrupts: usize,
    data: Cursor<Vec<u8>>,
}

impl Read for InterruptedThenData {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        if self.remaining_interrupts > 0 {
            self.remaining_interrupts -= 1;
            return Err(io::ErrorKind::Interrupted.into());
        }
        self.data.read(buf)
    }
}

#[test]
fn interrupted_reads_retry_without_losing_the_record() {
    let mut reader = FrameReader::new(InterruptedThenData {
        remaining_interrupts: 2,
        data: Cursor::new(b"record\n".to_vec()),
    });
    assert_eq!(reader.read_frame().unwrap(), Some(b"record".to_vec()));
}

struct FailingRead {
    accessed: bool,
}

impl Read for FailingRead {
    fn read(&mut self, _: &mut [u8]) -> io::Result<usize> {
        assert!(!self.accessed, "poisoned input was accessed again");
        self.accessed = true;
        Err(io::ErrorKind::ConnectionReset.into())
    }
}

#[test]
fn read_failure_closes_direction_without_reaccess() {
    let mut reader = FrameReader::new(FailingRead { accessed: false });
    assert_eq!(
        reader.read_frame().unwrap_err().kind(),
        io::ErrorKind::ConnectionReset
    );
    assert_eq!(
        reader.read_frame().unwrap_err().kind(),
        io::ErrorKind::BrokenPipe
    );
}

#[test]
fn writer_preserves_payload_and_adds_one_lf() {
    let mut bytes = Vec::new();
    {
        let mut writer = FrameWriter::new(&mut bytes);
        writer.write_frame(b"one").unwrap();
        writer.write_frame("α".as_bytes()).unwrap();
    }
    assert_eq!(bytes, "one\nα\n".as_bytes());
}

#[test]
fn bad_outgoing_payload_never_touches_output_and_keeps_direction_usable() {
    let mut bytes = Vec::new();
    {
        let mut writer = FrameWriter::new(&mut bytes);
        let oversized = vec![b'x'; MAX_FRAME_BYTES + 1];
        for invalid in [b"".as_slice(), b"a\nb", b"a\rb", b"\xff", &oversized] {
            assert_eq!(
                writer.write_frame(invalid).unwrap_err().kind(),
                io::ErrorKind::InvalidInput
            );
        }
        writer.write_frame(b"valid").unwrap();
    }
    assert_eq!(bytes, b"valid\n");
}

#[test]
fn maximum_outgoing_record_is_accepted() {
    let mut bytes = Vec::new();
    FrameWriter::new(&mut bytes)
        .write_frame(&vec![b'x'; MAX_FRAME_BYTES])
        .unwrap();
    assert_eq!(bytes.len(), MAX_FRAME_BYTES + 1);
    assert_eq!(&bytes[..MAX_FRAME_BYTES], vec![b'x'; MAX_FRAME_BYTES]);
    assert_eq!(bytes[MAX_FRAME_BYTES], b'\n');
}

struct PartialFailure {
    bytes: Vec<u8>,
    failed: bool,
}

impl Write for PartialFailure {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        assert!(!self.failed, "poisoned output was accessed again");
        if self.bytes.is_empty() {
            let count = buf.len().min(3);
            self.bytes.extend_from_slice(&buf[..count]);
            Ok(count)
        } else {
            self.failed = true;
            Err(io::ErrorKind::ConnectionReset.into())
        }
    }

    fn flush(&mut self) -> io::Result<()> {
        panic!("failed output must not be flushed");
    }
}

#[test]
fn partial_write_failure_cannot_be_retried_as_a_new_frame() {
    let mut output = PartialFailure {
        bytes: Vec::new(),
        failed: false,
    };
    {
        let mut writer = FrameWriter::new(&mut output);
        assert_eq!(
            writer.write_frame(b"record").unwrap_err().kind(),
            io::ErrorKind::ConnectionReset
        );
        assert_eq!(
            writer.write_frame(b"next").unwrap_err().kind(),
            io::ErrorKind::BrokenPipe
        );
    }
    assert_eq!(output.bytes, b"rec");
}

struct FlushFailure {
    bytes: Vec<u8>,
    failed: bool,
}

impl Write for FlushFailure {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        assert!(!self.failed, "poisoned output was accessed again");
        self.bytes.extend_from_slice(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        assert!(!self.failed, "poisoned output was flushed again");
        self.failed = true;
        Err(io::ErrorKind::ConnectionReset.into())
    }
}

#[test]
fn failed_flush_is_terminal_even_if_all_record_bytes_were_written() {
    let mut output = FlushFailure {
        bytes: Vec::new(),
        failed: false,
    };
    {
        let mut writer = FrameWriter::new(&mut output);
        assert_eq!(
            writer.write_frame(b"record").unwrap_err().kind(),
            io::ErrorKind::ConnectionReset
        );
        assert_eq!(
            writer.write_frame(b"next").unwrap_err().kind(),
            io::ErrorKind::BrokenPipe
        );
    }
    assert_eq!(output.bytes, b"record\n");
}

struct DelimiterFailure {
    bytes: Vec<u8>,
    failed: bool,
}

impl Write for DelimiterFailure {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        assert!(!self.failed, "poisoned output was accessed again");
        if buf == b"\n" {
            self.failed = true;
            return Err(io::ErrorKind::ConnectionReset.into());
        }
        self.bytes.extend_from_slice(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        panic!("delimiter failure must not be flushed");
    }
}

#[test]
fn delimiter_write_failure_leaves_an_unknown_unterminated_record() {
    let mut output = DelimiterFailure {
        bytes: Vec::new(),
        failed: false,
    };
    {
        let mut writer = FrameWriter::new(&mut output);
        assert_eq!(
            writer.write_frame(b"record").unwrap_err().kind(),
            io::ErrorKind::ConnectionReset
        );
        assert_eq!(
            writer.write_frame(b"next").unwrap_err().kind(),
            io::ErrorKind::BrokenPipe
        );
    }
    assert_eq!(output.bytes, b"record");
}

struct ZeroWrite {
    accessed: bool,
}

impl Write for ZeroWrite {
    fn write(&mut self, _: &[u8]) -> io::Result<usize> {
        assert!(!self.accessed, "poisoned output was accessed again");
        self.accessed = true;
        Ok(0)
    }

    fn flush(&mut self) -> io::Result<()> {
        panic!("zero-write failure must not be flushed");
    }
}

#[test]
fn zero_write_is_terminal() {
    let mut writer = FrameWriter::new(ZeroWrite { accessed: false });
    assert_eq!(
        writer.write_frame(b"record").unwrap_err().kind(),
        io::ErrorKind::WriteZero
    );
    assert_eq!(
        writer.write_frame(b"next").unwrap_err().kind(),
        io::ErrorKind::BrokenPipe
    );
}
