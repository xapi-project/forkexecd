(*
 * Copyright (C) Citrix Systems Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *)

let project_url = "http://github.com/xapi-project/forkexecd"

open Cmdliner

(* Help sections common to all commands *)

let _common_options = "COMMON OPTIONS"
let help = [
 `S _common_options;
 `P "These options are common to all commands.";
 `S "MORE HELP";
 `P "Use `$(mname) $(i,COMMAND) --help' for help on a single command."; `Noblank;
 `S "BUGS"; `P (Printf.sprintf "Check bug reports at %s" project_url);
]

module Common = struct
  type t = string
  let make x = x
end

(* Options common to all commands *)
let common_options_t =
  let docs = _common_options in
  let socket_dir =
    let doc = Printf.sprintf "Specify directory used to talk to the xapi-fe process." in
    Arg.(value & opt dir !Forkhelpers.socket_dir & info ["socket-dir"] ~docs ~doc) in
  Term.(pure Common.make $ socket_dir)

let run common cmd args =
  Forkhelpers.socket_dir := common;
  try
    let out, err = Forkhelpers.execute_command_get_output ~syslog_stdout:Forkhelpers.NoSyslogging cmd args in
    Printf.printf "stdout=[%s]\n" out;
    Printf.printf "stderr=[%s]\n" err;
    exit 0
  with Unix.Unix_error(_, _, _) as e ->
    Printf.fprintf stderr "Caught %s talking to xapi-fe daemon.\n" (Printexc.to_string e);
    Printf.fprintf stderr "Please check whether the socket-dir is valid (%s)\n" !Forkhelpers.socket_dir;
    exit 1
  | Forkhelpers.Spawn_internal_error(err, out, ps) ->
    Printf.fprintf stderr "stdout=[%s]\n" out;
    Printf.fprintf stderr "stderr=[%s]\n" err;
    let n =
    match ps with
    | Unix.WEXITED n ->
        Printf.fprintf stderr "WEXITED %d\n" n;
        n
    | Unix.WSTOPPED n ->
        Printf.fprintf stderr "WSTOPPED %d\n" n;
        n
    | Unix.WSIGNALED n ->
        Printf.fprintf stderr "WSIGNALED %d\n" n;
        n in
    exit n

(* Simple command-line test program which invokes the FE service *)
let cmd =
  let doc = "create a process" in
  let man = [
    `S "DESCRIPTION";
    `P "Creates a process via the xapi-fe service and returns the output.";
  ] @ help in
  let cmd =
    let doc = "Path to binary" in
    Arg.(value & pos 0 string "/bin/echo" & info [] ~docv:"COMMAND") in
  let args =
    let doc = "Arguments for the process" in
    Arg.(value & pos_right 1 string [] & info [] ~docv:"ARGUMENTS") in
  Term.(ret(pure run $ common_options_t $ cmd $ args)),
  Term.info "cmd" ~sdocs:_common_options ~doc ~man

let _ =
  match Term.eval cmd with
  | `Error _ -> exit 1
  | _ -> exit 0
