using System.Interop;
using System;
namespace lz4_beef;

public class LZ4
{
	public const int LZ4_MEMORY_USAGE_MIN = 10;
	public const int LZ4_MEMORY_USAGE_DEFAULT = 14;
	public const int LZ4_MEMORY_USAGE_MAX = 20;
	public const int LZ4_MEMORY_USAGE = LZ4_MEMORY_USAGE_DEFAULT;
	public const int LZ4_STREAMDECODE_MINSIZE = 32;
	public const int LZ4_HASHLOG =    (LZ4_MEMORY_USAGE - 2);
	public const int LZ4_HASHTABLESIZE = (1 << LZ4_MEMORY_USAGE);
	public const int LZ4_HASH_SIZE_U32 = (1 << LZ4_HASHLOG);
	public const int LZ4_STREAM_MINSIZE =  ((1UL << LZ4_MEMORY_USAGE) + 32);
	typealias LZ4_stream_t = LZ4_stream_u;
	typealias LZ4_streamDecode_t = LZ4_streamDecode_u;
	typealias LZ4_i8 = c_char;
	typealias LZ4_byte = c_char;
	typealias LZ4_u16 = c_char;
	typealias LZ4_u32 = c_int;

	/*-************************************
	*  Simple Functions
	**************************************/
	/*! LZ4_compress_default() :
	 *  Compresses 'srcSize' bytes from buffer 'src'
	 *  into already allocated 'dst' buffer of size 'dstCapacity'.
	 *  Compression is guaranteed to succeed if 'dstCapacity' >= LZ4_compressBound(srcSize).
	 *  It also runs faster, so it's a recommended setting.
	 *  If the function cannot compress 'src' into a more limited 'dst' budget,
	 *  compression stops *immediately*, and the function result is zero.
	 *  In which case, 'dst' content is undefined (invalid).
	 *      srcSize : max supported value is LZ4_MAX_INPUT_SIZE.
	 *      dstCapacity : size of buffer 'dst' (which must be already allocated)
	 *     @return  : the number of bytes written into buffer 'dst' (necessarily <= dstCapacity)
	 *                or 0 if compression fails
	 * Note : This function is protected against buffer overflow scenarios (never writes outside 'dst' buffer, nor read outside 'source' buffer).
	 */
	[CLink]
	public static extern int32 LZ4_compress_default(c_char* src, c_char* dst, c_int srcSize, c_int dstCapacity);

	/*! LZ4_decompress_safe() :
	 *  compressedSize : is the exact complete size of the compressed block.
	 *  dstCapacity : is the size of destination buffer (which must be already allocated), presumed an upper bound of decompressed size.
	 * @return : the number of bytes decompressed into destination buffer (necessarily <= dstCapacity)
	 *           If destination buffer is not large enough, decoding will stop and output an error code (negative value).
	 *           If the source stream is detected malformed, the function will stop decoding and return a negative result.
	 * Note 1 : This function is protected against malicious data packets :
	 *          it will never writes outside 'dst' buffer, nor read outside 'source' buffer,
	 *          even if the compressed block is maliciously modified to order the decoder to do these actions.
	 *          In such case, the decoder stops immediately, and considers the compressed block malformed.
	 * Note 2 : compressedSize and dstCapacity must be provided to the function, the compressed block does not contain them.
	 *          The implementation is free to send / store / derive this information in whichever way is most beneficial.
	 *          If there is a need for a different format which bundles together both compressed data and its metadata, consider looking at lz4frame.h instead.
	 */
	[CLink]
	public static extern int32 LZ4_decompress_safe (c_char* src, c_char* dst, c_int compressedSize, c_int dstCapacity);


	/*-************************************
	*  Advanced Functions
	**************************************/

	/*! LZ4_compressBound() :
	    Provides the maximum size that LZ4 compression may output in a "worst case" scenario (input data not compressible)
	    This function is primarily useful for memory allocation purposes (destination buffer size).
	    Macro LZ4_COMPRESSBOUND() is also provided for compilation-time evaluation (stack memory allocation for example).
	    Note that LZ4_compress_default() compresses faster when dstCapacity is >= LZ4_compressBound(srcSize)
	        inputSize  : max supported value is LZ4_MAX_INPUT_SIZE
	        return : maximum output size in a "worst case" scenario
	              or 0, if input size is incorrect (too large or negative)
	*/
	[CLink]
	public static extern int32 LZ4_compressBound(c_int inputSize);

	/*! LZ4_compress_fast() :
	    Same as LZ4_compress_default(), but allows selection of "acceleration" factor.
	    The larger the acceleration value, the faster the algorithm, but also the lesser the compression.
	    It's a trade-off. It can be fine tuned, with each successive value providing roughly +~3% to speed.
	    An acceleration value of "1" is the same as regular LZ4_compress_default()
	    Values <= 0 will be replaced by LZ4_ACCELERATION_DEFAULT (currently == 1, see lz4.c).
	    Values > LZ4_ACCELERATION_MAX will be replaced by LZ4_ACCELERATION_MAX (currently == 65537, see lz4.c).
	*/
	[CLink]
	public static extern int32 LZ4_compress_fast (c_char* src, c_char* dst, c_int srcSize, c_int dstCapacity, c_int acceleration);


	/*! LZ4_compress_fast_extState() :
	 *  Same as LZ4_compress_fast(), using an externally allocated memory space for its state.
	 *  Use LZ4_sizeofState() to know how much memory must be allocated,
	 *  and allocate it on 8-bytes boundaries (using `malloc()` typically).
	 *  Then, provide this buffer as `void* state` to compression function.
	 */
	[CLink]
	public static extern int32 LZ4_sizeofState();

	[CLink]
	public static extern int32 LZ4_compress_fast_extState (void* state, c_char* src, c_char* dst, c_int srcSize, c_int dstCapacity, c_int acceleration);


	/*! LZ4_compress_destSize() :
	 *  Reverse the logic : compresses as much data as possible from 'src' buffer
	 *  into already allocated buffer 'dst', of size >= 'targetDestSize'.
	 *  This function either compresses the entire 'src' content into 'dst' if it's large enough,
	 *  or fill 'dst' buffer completely with as much data as possible from 'src'.
	 *  note: acceleration parameter is fixed to "default".
	 *
	 * *srcSizePtr : will be modified to indicate how many bytes where read from 'src' to fill 'dst'.
	 *               New value is necessarily <= input value.
	 * @return : Nb bytes written into 'dst' (necessarily <= targetDestSize)
	 *           or 0 if compression fails.
	 *
	 * Note : from v1.8.2 to v1.9.1, this function had a bug (fixed un v1.9.2+):
	 *        the produced compressed content could, in specific circumstances,
	 *        require to be decompressed into a destination buffer larger
	 *        by at least 1 byte than the content to decompress.
	 *        If an application uses `LZ4_compress_destSize()`,
	 *        it's highly recommended to update liblz4 to v1.9.2 or better.
	 *        If this can't be done or ensured,
	 *        the receiving decompression function should provide
	 *        a dstCapacity which is > decompressedSize, by at least 1 byte.
	 *        See https://github.com/lz4/lz4/issues/859 for details
	 */
	[CLink]
	public static extern int32 LZ4_compress_destSize (c_char* src, c_char* dst, c_int* srcSizePtr, c_int targetDstSize);


	/*! LZ4_decompress_safe_partial() :
	 *  Decompress an LZ4 compressed block, of size 'srcSize' at position 'src',
	 *  into destination buffer 'dst' of size 'dstCapacity'.
	 *  Up to 'targetOutputSize' bytes will be decoded.
	 *  The function stops decoding on reaching this objective.
	 *  This can be useful to boost performance
	 *  whenever only the beginning of a block is required.
	 *
	 * @return : the number of bytes decoded in `dst` (necessarily <= targetOutputSize)
	 *           If source stream is detected malformed, function returns a negative result.
	 *
	 *  Note 1 : @return can be < targetOutputSize, if compressed block contains less data.
	 *
	 *  Note 2 : targetOutputSize must be <= dstCapacity
	 *
	 *  Note 3 : this function effectively stops decoding on reaching targetOutputSize,
	 *           so dstCapacity is kind of redundant.
	 *           This is because in older versions of this function,
	 *           decoding operation would still write complete sequences.
	 *           Therefore, there was no guarantee that it would stop writing at exactly targetOutputSize,
	 *           it could write more bytes, though only up to dstCapacity.
	 *           Some "margin" used to be required for this operation to work properly.
	 *           Thankfully, this is no longer necessary.
	 *           The function nonetheless keeps the same signature, in an effort to preserve API compatibility.
	 *
	 *  Note 4 : If srcSize is the exact size of the block,
	 *           then targetOutputSize can be any value,
	 *           including larger than the block's decompressed size.
	 *           The function will, at most, generate block's decompressed size.
	 *
	 *  Note 5 : If srcSize is _larger_ than block's compressed size,
	 *           then targetOutputSize **MUST** be <= block's decompressed size.
	 *           Otherwise, *silent corruption will occur*.
	 */
	[CLink]
	public static extern int32 LZ4_decompress_safe_partial (c_char* src, c_char* dst, c_int srcSize, c_int targetOutputSize, c_int dstCapacity);


	/*-*********************************************
	*  Streaming Compression Functions
	***********************************************/
	/**
	 Note about RC_INVOKED

	 - RC_INVOKED is predefined symbol of rc.exe (the resource compiler which is part of MSVC/Visual Studio).
	   https://docs.microsoft.com/en-us/windows/win32/menurc/predefined-macros

	 - Since rc.exe is a legacy compiler, it truncates long symbol (> 30 chars)
	   and reports warning "RC4011: identifier truncated".

	 - To eliminate the warning, we surround long preprocessor symbol with
	   "#if !defined(RC_INVOKED) ... #endif" block that means
	   "skip this block when rc.exe is trying to read it".
	*/
	[CLink]
	public static extern LZ4_stream_t* LZ4_createStream();

	[CLink]
	public static extern int32 LZ4_freeStream (LZ4_stream_t* streamPtr);

	/*! LZ4_resetStream_fast() : v1.9.0+
	 *  Use this to prepare an LZ4_stream_t for a new chain of dependent blocks
	 *  (e.g., LZ4_compress_fast_continue()).
	 *
	 *  An LZ4_stream_t must be initialized once before usage.
	 *  This is automatically done when created by LZ4_createStream().
	 *  However, should the LZ4_stream_t be simply declared on stack (for example),
	 *  it's necessary to initialize it first, using LZ4_initStream().
	 *
	 *  After init, start any new stream with LZ4_resetStream_fast().
	 *  A same LZ4_stream_t can be re-used multiple times consecutively
	 *  and compress multiple streams,
	 *  provided that it starts each new stream with LZ4_resetStream_fast().
	 *
	 *  LZ4_resetStream_fast() is much faster than LZ4_initStream(),
	 *  but is not compatible with memory regions containing garbage data.
	 *
	 *  Note: it's only useful to call LZ4_resetStream_fast()
	 *        in the context of streaming compression.
	 *        The *extState* functions perform their own resets.
	 *        Invoking LZ4_resetStream_fast() before is redundant, and even counterproductive.
	 */
	[CLink]
	public static extern void LZ4_resetStream_fast (LZ4_stream_t* streamPtr);

	/*! LZ4_loadDict() :
	 *  Use this function to reference a static dictionary into LZ4_stream_t.
	 *  The dictionary must remain available during compression.
	 *  LZ4_loadDict() triggers a reset, so any previous data will be forgotten.
	 *  The same dictionary will have to be loaded on decompression side for successful decoding.
	 *  Dictionary are useful for better compression of small data (KB range).
	 *  While LZ4 accept any input as dictionary,
	 *  results are generally better when using Zstandard's Dictionary Builder.
	 *  Loading a size of 0 is allowed, and is the same as reset.
	 * @return : loaded dictionary size, in bytes (necessarily <= 64 KB)
	 */
	[CLink]
	public static extern int32 LZ4_loadDict (LZ4_stream_t* streamPtr, c_char* dictionary, c_int dictSize);

	/*! LZ4_compress_fast_continue() :
	 *  Compress 'src' content using data from previously compressed blocks, for better compression ratio.
	 * 'dst' buffer must be already allocated.
	 *  If dstCapacity >= LZ4_compressBound(srcSize), compression is guaranteed to succeed, and runs faster.
	 *
	 * @return : size of compressed block
	 *           or 0 if there is an error (typically, cannot fit into 'dst').
	 *
	 *  Note 1 : Each invocation to LZ4_compress_fast_continue() generates a new block.
	 *           Each block has precise boundaries.
	 *           Each block must be decompressed separately, calling LZ4_decompress_*() with relevant metadata.
	 *           It's not possible to append blocks together and expect a single invocation of LZ4_decompress_*() to decompress them together.
	 *
	 *  Note 2 : The previous 64KB of source data is __assumed__ to remain present, unmodified, at same address in memory !
	 *
	 *  Note 3 : When input is structured as a double-buffer, each buffer can have any size, including < 64 KB.
	 *           Make sure that buffers are separated, by at least one byte.
	 *           This construction ensures that each block only depends on previous block.
	 *
	 *  Note 4 : If input buffer is a ring-buffer, it can have any size, including < 64 KB.
	 *
	 *  Note 5 : After an error, the stream status is undefined (invalid), it can only be reset or freed.
	 */
	[CLink]
	public static extern int32 LZ4_compress_fast_continue (LZ4_stream_t* streamPtr, c_char* src, c_char* dst, c_int srcSize, c_int dstCapacity, c_int acceleration);

	/*! LZ4_saveDict() :
	 *  If last 64KB data cannot be guaranteed to remain available at its current memory location,
	 *  save it into a safer place (char* safeBuffer).
	 *  This is schematically equivalent to a memcpy() followed by LZ4_loadDict(),
	 *  but is much faster, because LZ4_saveDict() doesn't need to rebuild tables.
	 * @return : saved dictionary size in bytes (necessarily <= maxDictSize), or 0 if error.
	 */
	[CLink]
	public static extern int32 LZ4_saveDict (LZ4_stream_t* streamPtr, c_char* safeBuffer, c_int maxDictSize);


	/*-**********************************************
	*  Streaming Decompression Functions
	*  Bufferless synchronous API
	************************************************/
   /* tracking context */

	/*! LZ4_createStreamDecode() and LZ4_freeStreamDecode() :
	 *  creation / destruction of streaming decompression tracking context.
	 *  A tracking context can be re-used multiple times.
	 */
	[CLink]
	public static extern LZ4_streamDecode_t* LZ4_createStreamDecode();

	[CLink]
	public static extern int32 LZ4_freeStreamDecode (LZ4_streamDecode_t* LZ4_stream);


	/*! LZ4_setStreamDecode() :
	 *  An LZ4_streamDecode_t context can be allocated once and re-used multiple times.
	 *  Use this function to start decompression of a new stream of blocks.
	 *  A dictionary can optionally be set. Use NULL or size 0 for a reset order.
	 *  Dictionary is presumed stable : it must remain accessible and unmodified during next decompression.
	 * @return : 1 if OK, 0 if error
	 */
	[CLink]
	public static extern int32 LZ4_setStreamDecode (LZ4_streamDecode_t* LZ4_streamDecode, c_char* dictionary, c_int dictSize);

	/*! LZ4_decoderRingBufferSize() : v1.8.2+
	 *  Note : in a ring buffer scenario (optional),
	 *  blocks are presumed decompressed next to each other
	 *  up to the moment there is not enough remaining space for next block (remainingSize < maxBlockSize),
	 *  at which stage it resumes from beginning of ring buffer.
	 *  When setting such a ring buffer for streaming decompression,
	 *  provides the minimum size of this ring buffer
	 *  to be compatible with any source respecting maxBlockSize condition.
	 * @return : minimum ring buffer size,
	 *           or 0 if there is an error (invalid maxBlockSize).
	 */
	[CLink]
	public static extern int32 LZ4_decoderRingBufferSize(c_int maxBlockSize);

	/*! LZ4_decompress_*_continue() :
	 *  These decoding functions allow decompression of consecutive blocks in "streaming" mode.
	 *  A block is an unsplittable entity, it must be presented entirely to a decompression function.
	 *  Decompression functions only accepts one block at a time.
	 *  The last 64KB of previously decoded data *must* remain available and unmodified at the memory position where they were decoded.
	 *  If less than 64KB of data has been decoded, all the data must be present.
	 *
	 *  Special : if decompression side sets a ring buffer, it must respect one of the following conditions :
	 *  - Decompression buffer size is _at least_ LZ4_decoderRingBufferSize(maxBlockSize).
	 *    maxBlockSize is the maximum size of any single block. It can have any value > 16 bytes.
	 *    In which case, encoding and decoding buffers do not need to be synchronized.
	 *    Actually, data can be produced by any source compliant with LZ4 format specification, and respecting maxBlockSize.
	 *  - Synchronized mode :
	 *    Decompression buffer size is _exactly_ the same as compression buffer size,
	 *    and follows exactly same update rule (block boundaries at same positions),
	 *    and decoding function is provided with exact decompressed size of each block (exception for last block of the stream),
	 *    _then_ decoding & encoding ring buffer can have any size, including small ones ( < 64 KB).
	 *  - Decompression buffer is larger than encoding buffer, by a minimum of maxBlockSize more bytes.
	 *    In which case, encoding and decoding buffers do not need to be synchronized,
	 *    and encoding ring buffer can have any size, including small ones ( < 64 KB).
	 *
	 *  Whenever these conditions are not possible,
	 *  save the last 64KB of decoded data into a safe buffer where it can't be modified during decompression,
	 *  then indicate where this data is saved using LZ4_setStreamDecode(), before decompressing next block.
	*/
	[CLink]
	public static extern int32 LZ4_decompress_safe_continue (LZ4_streamDecode_t* LZ4_streamDecode,
	                        c_char* src, c_char* dst,
	                        c_int srcSize, c_int dstCapacity);


	/*! LZ4_decompress_*_usingDict() :
	 *  These decoding functions work the same as
	 *  a combination of LZ4_setStreamDecode() followed by LZ4_decompress_*_continue()
	 *  They are stand-alone, and don't need an LZ4_streamDecode_t structure.
	 *  Dictionary is presumed stable : it must remain accessible and unmodified during decompression.
	 *  Performance tip : Decompression speed can be substantially increased
	 *                    when dst == dictStart + dictSize.
	 */
	[CLink]
	public static extern int32 LZ4_decompress_safe_usingDict(c_char* src, c_char* dst,
	                              c_int srcSize, c_int dstCapacity,
	                              c_char* dictStart, c_int dictSize);
	[CLink]
	public static extern int32 LZ4_decompress_safe_partial_usingDict(c_char* src, c_char* dst,
	                                      c_int compressedSize,
	                                      c_int targetOutputSize, c_int maxOutputSize,
	                                      c_char* dictStart, c_int dictSize);


	/*! LZ4_compress_fast_extState_fastReset() :
	 *  A variant of LZ4_compress_fast_extState().
	 *
	 *  Using this variant avoids an expensive initialization step.
	 *  It is only safe to call if the state buffer is known to be correctly initialized already
	 *  (see above comment on LZ4_resetStream_fast() for a definition of "correctly initialized").
	 *  From a high level, the difference is that
	 *  this function initializes the provided state with a call to something like LZ4_resetStream_fast()
	 *  while LZ4_compress_fast_extState() starts with a call to LZ4_resetStream().
	 */
	[CLink]
	public static extern int32 LZ4_compress_fast_extState_fastReset (void* state, c_char* src, c_char* dst, c_int srcSize, c_int dstCapacity, c_int acceleration);

	/*! LZ4_attach_dictionary() :
	 *  This is an experimental API that allows
	 *  efficient use of a static dictionary many times.
	 *
	 *  Rather than re-loading the dictionary buffer into a working context before
	 *  each compression, or copying a pre-loaded dictionary's LZ4_stream_t into a
	 *  working LZ4_stream_t, this function introduces a no-copy setup mechanism,
	 *  in which the working stream references the dictionary stream in-place.
	 *
	 *  Several assumptions are made about the state of the dictionary stream.
	 *  Currently, only streams which have been prepared by LZ4_loadDict() should
	 *  be expected to work.
	 *
	 *  Alternatively, the provided dictionaryStream may be NULL,
	 *  in which case any existing dictionary stream is unset.
	 *
	 *  If a dictionary is provided, it replaces any pre-existing stream history.
	 *  The dictionary contents are the only history that can be referenced and
	 *  logically immediately precede the data compressed in the first subsequent
	 *  compression call.
	 *
	 *  The dictionary will only remain attached to the working stream through the
	 *  first compression call, at the end of which it is cleared. The dictionary
	 *  stream (and source buffer) must remain in-place / accessible / unchanged
	 *  through the completion of the first compression call on the stream.
	 */
	[CLink]
	public static extern void LZ4_attach_dictionary(LZ4_stream_t* workingStream, LZ4_stream_t* dictionaryStream);

	/*-************************************************************
	 *  Private Definitions
	 **************************************************************
	 * Do not use these definitions directly.
	 * They are only exposed to allow static allocation of `LZ4_stream_t` and `LZ4_streamDecode_t`.
	 * Accessing members will expose user code to API and/or ABI break in future versions of the library.
	 **************************************************************/
	 
	  //typedef   signed char  LZ4_i8;
	  //typedef unsigned char  LZ4_byte;
	  //typedef unsigned short LZ4_u16;
	  //typedef unsigned int   LZ4_u32;

	/*! LZ4_stream_t :
	 *  Never ever use below internal definitions directly !
	 *  These definitions are not API/ABI safe, and may change in future versions.
	 *  If you need static allocation, declare or allocate an LZ4_stream_t object.
	**/
	[CRepr]
	public struct LZ4_stream_t_internal {
	    LZ4_u32[LZ4_HASH_SIZE_U32] hashTable;
	    LZ4_byte* dictionary;
	    LZ4_stream_t_internal* dictCtx;
	    LZ4_u32 currentOffset;
	    LZ4_u32 tableType;
	    LZ4_u32 dictSize;
	    /* Implicit padding to ensure structure is aligned */
	};

  /* static size, for inter-version compatibility */
	[Union]
	[CRepr]
	public struct LZ4_stream_u {
	    c_char[LZ4_STREAM_MINSIZE] minStateSize;
	    LZ4_stream_t_internal internal_donotuse;
	}; /* previously typedef'd to LZ4_stream_t */


	/*! LZ4_initStream() : v1.9.0+
	 *  An LZ4_stream_t structure must be initialized at least once.
	 *  This is automatically done when invoking LZ4_createStream(),
	 *  but it's not when the structure is simply declared on stack (for example).
	 *
	 *  Use LZ4_initStream() to properly initialize a newly declared LZ4_stream_t.
	 *  It can also initialize any arbitrary buffer of sufficient size,
	 *  and will @return a pointer of proper type upon initialization.
	 *
	 *  Note : initialization fails if size and alignment conditions are not respected.
	 *         In which case, the function will @return NULL.
	 *  Note2: An LZ4_stream_t structure guarantees correct alignment and size.
	 *  Note3: Before v1.9.0, use LZ4_resetStream() instead
	**/
	[CLink]
	public static extern LZ4_stream_t* LZ4_initStream (void* buffer, c_intptr size);


	/*! LZ4_streamDecode_t :
	 *  Never ever use below internal definitions directly !
	 *  These definitions are not API/ABI safe, and may change in future versions.
	 *  If you need static allocation, declare or allocate an LZ4_streamDecode_t object.
	**/
	[CRepr]
	public struct LZ4_streamDecode_t_internal{
	    LZ4_byte* externalDict;
	    LZ4_byte* prefixEnd;
	    c_intptr extDictSize; //size_t
	    c_intptr prefixSize;
	}

	[Union]
	[CRepr]
	public struct LZ4_streamDecode_u {
	    c_char[LZ4_STREAMDECODE_MINSIZE] minStateSize;
	    LZ4_streamDecode_t_internal internal_donotuse;
	} ;   /* previously typedef'd to LZ4_streamDecode_t */



	/*! LZ4_resetStream() :
	 *  An LZ4_stream_t structure must be initialized at least once.
	 *  This is done with LZ4_initStream(), or LZ4_resetStream().
	 *  Consider switching to LZ4_initStream(),
	 *  invoking LZ4_resetStream() will trigger deprecation warnings in the future.
	 */
	[CLink]
	public static extern void LZ4_resetStream (LZ4_stream_t* streamPtr);
}