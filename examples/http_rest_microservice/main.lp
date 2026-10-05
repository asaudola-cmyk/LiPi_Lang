// ==============================================================================
// 🌐 LIPI ZERO-COPY HTTP/1.1 REST MICROSERVICE (examples/http_rest_microservice/main.lp)
// ⚡ 100% Pure Lipi | Linux io_uring Kernel-Bypass Architecture | 0% Libc | 0% C++
// Features: Zero-Copy Request Lexing, Fast JSON Serialization, Keep-Alive Lifecycle,
//           Socket Timeout Resilience, and High-Throughput RESTful Endpoints.
// ==============================================================================
//
// WHY: A production-ready HTTP microservice utilizing the io_uring zero-copy
// network reactor, enabling high-performance REST APIs without OS thread bloat.
// ==============================================================================

import "examples/http_rest_microservice/microservice_core.lp"

fn main()
  println("══════════════════════════════════════════════════════════════════════")
  println("⚡ LIPI ZERO-COPY HTTP/1.1 REST MICROSERVICE (IO_URING BYPASS)")
  println("══════════════════════════════════════════════════════════════════════")

  // Default configuration
  port = 8081
  max_requests = 0 // 0 = continuous production daemon

  // Parse command-line arguments if passed: [binary, port, max_requests]
  cli_args = argv()
  argc = cli_args.len()
  if argc >= 2
    p_arg = cli_args[1]
    if str_len(p_arg) > 0
      p_acc = 0
      pi = 0
      while pi < str_len(p_arg)
        pc = ord(char_at(p_arg, pi))
        if pc >= 48 && pc <= 57
          p_acc = (p_acc * 10) + (pc - 48)
        end
        pi = pi + 1
      end
      if p_acc > 0 port = p_acc end
    end
  end

  if argc >= 3
    m_arg = cli_args[2]
    if str_len(m_arg) > 0
      m_acc = 0
      mi = 0
      while mi < str_len(m_arg)
        mc = ord(char_at(m_arg, mi))
        if mc >= 48 && mc <= 57
          m_acc = (m_acc * 10) + (mc - 48)
        end
        mi = mi + 1
      end
      max_requests = m_acc
    end
  end

  return microservice_run_server(port, max_requests)
end

main()
