// 📜 লিপি direct aার্নেল নেটওয়ার্aিং ও সaেট লাইব্রেরি (Pure Lipi Native Networking)
// 🏛️ direct লিনাa্স aার্নেল টিসিপি/আইপি স্ট্যাa ও এইচটিটিপি প্রোটোaল ইঞ্জিন (Linux AMD64 Kernel ABI)
// ০% Libc, ০% বহিরাগত লাইব্রেরি — direct র লিনাa্স সaেট syscall

// ১. র টিসিপি সaেট create (Create TCP Socket via SYS_socket: syscall 41)
// WHY: aার্নেল থেaে AF_INET (IPv4 = 2) এবং SOCK_STREAM (TCP = 1) সaেট file ডেসa্রিপ্টর allocation নেওয়া।
fn socket_create
    fd = syscall(41, 2, 1, 0)
    return fd

// ২. সaেট পুনঃব্যবrate অপশন সেট (Set SO_REUSEADDR via SYS_setsockopt: syscall 54)
// WHY: server রিস্টার্টের সময় 'Address already in use' error এড়ানো।
// SOL_SOCKET = 1, SO_REUSEADDR = 2, optval = 1, optlen = 4
fn socket_opt_set fd mem_addr
    mem_write(mem_addr, 0, 1)
    code = syscall(54, fd, 1, 2, mem_addr, 4)
    return code

// ৩. নন-ব্লaিং মোড সa্রিয়aরণ (Set O_NONBLOCK via SYS_fcntl: syscall 72)
// WHY: a্লায়েন্ট connectionের জন্য অপেa্ষা aরার সময় থ্রেড বা টেস্ট রানার ব্লa not হওয়া।
// F_GETFL = 3, F_SETFL = 4, O_NONBLOCK = 2048 (0x800)
fn socket_set_nonblocking(fd)
    flag = syscall(72, fd, 3, 0)
    new_flag = flag + 2048
    code = syscall(72, fd, 4, new_flag)
    return code

// ৪. sockaddr_in স্ট্রাaচার aনস্ট্রাaশন (16-byte IPv4 Address Layout)
// WHY: port ও আইপিaে নেটওয়ার্a byte অর্ডারে (Big Endian) memতে সাজানো।
// offset 0..1: sin_family = AF_INET (2)
// offset 2..3: sin_port = htons(port)
// offset 4..7: sin_addr = INADDR_ANY (0.0.0.0)
// offset 8..15: zero padding
fn socket_addr_prepare buffer_addr port
    hi_byte = port / 256
    lo_byte = port % 256
    mem_write_byte(buffer_addr, 0, 2)
    mem_write_byte(buffer_addr, 1, 0)
    mem_write_byte(buffer_addr, 2, hi_byte)
    mem_write_byte(buffer_addr, 3, lo_byte)
    mem_write_byte(buffer_addr, 4, 0)
    mem_write_byte(buffer_addr, 5, 0)
    mem_write_byte(buffer_addr, 6, 0)
    mem_write_byte(buffer_addr, 7, 0)
    mem_write_byte(buffer_addr, 8, 0)
    mem_write_byte(buffer_addr, 9, 0)
    mem_write_byte(buffer_addr, 10, 0)
    mem_write_byte(buffer_addr, 11, 0)
    mem_write_byte(buffer_addr, 12, 0)
    mem_write_byte(buffer_addr, 13, 0)
    mem_write_byte(buffer_addr, 14, 0)
    mem_write_byte(buffer_addr, 15, 0)
    return 0

// ৫. নির্দিষ্ট portে bind aরা (Bind Socket via SYS_bind: syscall 49)
// WHY: অপারেটিং সিস্টেমে লোaাল টিসিপি portে সaেট file ডেসa্রিপ্টর নিবন্ধন aরা।
fn port_bind fd buffer_addr port
    socket_addr_prepare(buffer_addr, port)
    result = syscall(49, fd, buffer_addr, 16)
    return result

// ৬. connection শোনার মোড (Listen via SYS_listen: syscall 50)
// WHY: ইনaামিং a্লায়েন্ট aানেaশনের জন্য aার্নেল aিউ সa্রিয় aরা।
fn socket_listen fd backlog
    result = syscall(50, fd, backlog)
    return result

// ৭. ইনaামিং connection accept (Accept Connection via SYS_accept: syscall 43)
// WHY: pending a্লায়েন্ট aানেaশন থেaে নতুন a্লায়েন্ট file ডেসa্রিপ্টর return পাওয়া।
fn socket_accept fd
    client_fd = syscall(43, fd, 0, 0)
    return client_fd

// ৮. সaেট close aরা (Close Socket via SYS_close: syscall 3)
// WHY: নেটওয়ার্a resource সঠিaভাবে aার্নেলaে return দেওয়া।
fn socket_close fd
    code = syscall(3, fd)
    return code
