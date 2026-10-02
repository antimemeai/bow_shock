//! Bounded UTF-8 records for the controller's private pipes.
//!
//! These synchronous primitives belong on dedicated IO workers. They provide
//! byte limits and terminal framing faults, not deadlines or command authority.
//!
//! ```
//! use bow_shock_controller_link::{FrameReader, FrameWriter};
//! use std::io::Cursor;
//! let mut bytes = Vec::new();
//! FrameWriter::new(&mut bytes).write_frame(b"{\"version\":1}")?;
//! let mut reader = FrameReader::new(Cursor::new(bytes));
//! assert_eq!(reader.read_frame()?, Some(b"{\"version\":1}".to_vec()));
//! assert_eq!(reader.read_frame()?, None);
//! # Ok::<(), std::io::Error>(())
//! ```

use std::io::{self, BufRead, BufReader, Read, Write};

/// Maximum payload size, excluding the single LF delimiter.
pub const MAX_FRAME_BYTES: usize = 65_536;
const READ_BUFFER_BYTES: usize = 4096;

/// An owned buffered reader. Any corrupt/truncated frame or IO failure is terminal.
pub struct FrameReader<R> {
    inner: BufReader<R>,
    poisoned: bool,
}

impl<R: Read> FrameReader<R> {
    pub fn new(inner: R) -> Self {
        Self {
            inner: BufReader::with_capacity(READ_BUFFER_BYTES, inner),
            poisoned: false,
        }
    }

    pub fn read_frame(&mut self) -> io::Result<Option<Vec<u8>>> {
        if self.poisoned {
            return Err(io::ErrorKind::BrokenPipe.into());
        }
        let result = self.read_one();
        if result.is_err() {
            self.poisoned = true;
        }
        result
    }

    fn read_one(&mut self) -> io::Result<Option<Vec<u8>>> {
        let mut payload = Vec::with_capacity(MAX_FRAME_BYTES);
        loop {
            let available = match self.inner.fill_buf() {
                Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
                result => result?,
            };
            if available.is_empty() {
                return if payload.is_empty() {
                    Ok(None)
                } else {
                    Err(io::ErrorKind::UnexpectedEof.into())
                };
            }
            let newline = available.iter().position(|byte| *byte == b'\n');
            let count = newline.unwrap_or(available.len());
            if count > MAX_FRAME_BYTES - payload.len() {
                return Err(io::ErrorKind::InvalidData.into());
            }
            payload.extend_from_slice(&available[..count]);
            self.inner.consume(count + usize::from(newline.is_some()));
            if newline.is_some() {
                validate(&payload).map_err(|()| io::Error::from(io::ErrorKind::InvalidData))?;
                return Ok(Some(payload));
            }
        }
    }
}

/// A writer that rejects invalid payloads before IO and poisons on any IO failure.
pub struct FrameWriter<W> {
    inner: W,
    poisoned: bool,
}

impl<W: Write> FrameWriter<W> {
    pub fn new(inner: W) -> Self {
        Self {
            inner,
            poisoned: false,
        }
    }

    pub fn write_frame(&mut self, payload: &[u8]) -> io::Result<()> {
        if self.poisoned {
            return Err(io::ErrorKind::BrokenPipe.into());
        }
        validate(payload).map_err(|()| io::Error::from(io::ErrorKind::InvalidInput))?;
        let result = self
            .inner
            .write_all(payload)
            .and_then(|()| self.inner.write_all(b"\n"))
            .and_then(|()| self.inner.flush());
        if result.is_err() {
            self.poisoned = true;
        }
        result
    }
}

fn validate(payload: &[u8]) -> Result<(), ()> {
    if payload.is_empty()
        || payload.len() > MAX_FRAME_BYTES
        || payload.iter().any(|byte| matches!(byte, b'\r' | b'\n'))
        || std::str::from_utf8(payload).is_err()
    {
        return Err(());
    }
    Ok(())
}
