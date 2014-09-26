(* We'll create our control sockets here *)
let socket_dir = ref "/var/xapi/forker"

open Fe_debug

let setup sock cmdargs id_to_fd_map syslog_stdout env =
  let fd_sock_path = Printf.sprintf "%s/fd_%s"
    !socket_dir (Uuidm.to_string (Uuidm.create `V4)) in
  let fd_sock = Fecomms.open_unix_domain_sock () in
  Unixext.unlink_safe fd_sock_path;
  debug "About to bind to %s" fd_sock_path;
  Unix.bind fd_sock (Unix.ADDR_UNIX fd_sock_path);
  Unix.listen fd_sock 5;
  debug "bound, listening";
  let result = Unix.fork () in
  if result=0
  then begin
    debug "Child here!";
    let result2 = Unix.fork () in
    if result2=0 then begin
      debug "Grandchild here!";
      (* Grandchild *)
      let state = {
	Child.cmdargs=cmdargs;
	env=env;
	id_to_fd_map=id_to_fd_map;
	syslog_stdout={Child.enabled=syslog_stdout.Fe.enabled; Child.key=syslog_stdout.Fe.key};
	ids_received=[];
	fd_sock2=None;
	finished=false;
      } in
      Child.run state sock fd_sock fd_sock_path
    end else begin
      (* Child *)
      exit 0;
    end
  end else begin
    (* Parent *)
    debug "Waiting for process %d to exit" result;
    ignore(Unix.waitpid [] result);
    Unix.close fd_sock;
    Some {Fe.fd_sock_path=fd_sock_path}
  end

let doc = String.concat "\n" [
  "Xapi-fe is the xapi toolstack process management daemon.";
  "";
  "Xapi-fe looks after a set of subprocesses on behalf of xapi. The main xapi process avoids forking to avoid problems with pthreads.";
]

let _ =
  let options = [
    "socket-dir", Arg.Set_string socket_dir, (fun () -> !socket_dir), "Directory to place Unix domain sockets";
  ] in
  (match Xcp_service.configure2
    ~name:(Filename.basename Sys.argv.(0))
    ~version:Version.version
    ~doc ~options () with
  | `Ok () -> ()
  | `Error m ->
    error "%s" m;
    exit 1);

  Xcp_service.maybe_daemonize ();

  let main_sock =
    try
      Fecomms.open_unix_domain_sock_server (Filename.concat !socket_dir "main")
    with Unix.Unix_error(_,_,_) as e ->
      error "Failed to create Unix domain socket in %s: %s" !socket_dir (Printexc.to_string e);
      Printf.fprintf stderr "Please check the directory %s is what you intended; if not overrride it with --socket-dir=<DIR>.\n" !socket_dir;
      Printf.fprintf stderr "Please check the directory exists.\n";
      Printf.fprintf stderr "Please check this process has sufficient permissions to write in the directory.\n";
      exit 1 in

  (* At this point the init.d script should return and we are listening on our socket. *)

  while true do
    try
      let (sock,addr) = Unix.accept main_sock in
      reset ();
      let cmd = Fecomms.read_raw_rpc sock in
      match cmd with
	| Fe.Setup s ->
	    let result = setup sock s.Fe.cmdargs s.Fe.id_to_fd_map s.Fe.syslog_stdout s.Fe.env in
	    (match result with
	      | Some response ->
		  Fecomms.write_raw_rpc sock (Fe.Setup_response response);
		  Unix.close sock;
	      | _ -> ())
	| _ ->
	    debug "Ignoring invalid message";
	    Unix.close sock
    with e ->
      debug "Caught exception at top level: %s" (Printexc.to_string e);
  done
