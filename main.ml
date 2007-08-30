open Common open Commonop

(*****************************************************************************)
(* Flags *)
(*****************************************************************************)

(* In addition to flags that can be tweaked via -xxx options (cf the
 * full list of options in "the spatch options" section), the spatch
 * program also depends on external files, described in
 * globals/config.ml, mainly a standard.h and standard.iso file 
 *)

let cocci_file = ref ""

let output_file = ref ""
let inplace_modif = ref false  (* but keeps a .cocci_orig *)
let outplace_modif = ref false (* generates a .cocci_res  *)

let dir = ref false
let kbuild_info = ref ""

(* test mode *)
let test_mode = ref false
let test_all = ref false
let test_okfailed = ref false
let test_regression_okfailed = ref false

(* action mode *)
let action = ref ""

(* works with -test but also in "normal" spatch mode *)
let compare_with_expected = ref false

let save_tmp_files = ref false


(*****************************************************************************)
(* Profiles *)
(*****************************************************************************)

(* pair of  (list of flags to set true, list of flags to set false *)
let quiet_profile = (
  [
    Flag_cocci.show_diff;
  ],
  [
    Flag.show_misc;

    Flag_cocci.show_c;
    Flag_cocci.show_cocci;
    Flag_cocci.show_flow;
    Flag_cocci.show_before_fixed_flow;
    Flag_cocci.show_ctl_tex;
    Flag_cocci.show_ctl_text;
    Flag_cocci.show_transinfo;
    Flag_cocci.show_binding_in_out;

    Flag_parsing_cocci.show_SP;
    Flag_parsing_cocci.show_iso_failures;
    Flag_ctl.verbose_ctl_engine;
    Flag_engine.debug_engine;
    Flag_engine.debug_unparsing;
    Flag_parsing_c.verbose_type;
    Flag_parsing_c.verbose_parsing;
  ])

(*****************************************************************************)
(* The spatch options *)
(*****************************************************************************)

let usage_msg = 
  "Usage: " ^ basename Sys.argv.(0) ^ 
    " -sp_file <SP> <infile> [-o <outfile>] [-iso_file <iso>] [options]" ^ 
    "\n" ^ "Options are:"

(* forward reference trick *)
let short_usage_func = ref (fun () -> ())
let long_usage_func  = ref (fun () -> ())


(* The short_options are user-oriented. The other options are for
 * the developers of coccinelle or advanced-users that know
 * quite well the underlying semantics of coccinelle.
 *)
  

(* will be printed when use only ./spatch. For the rest you have to
 * use -longhelp to see them. 
 *)
let short_options = [ 
  "-sp_file",  Arg.Set_string cocci_file, " <file> the semantic patch file";

  "-o", Arg.Set_string output_file,
  "   <file> the output file";
  "-inplace", Arg.Set inplace_modif,
  "   do the modification on the file directly";
  "-outplace", Arg.Set outplace_modif,
  "   store modifications in a .cocci_res file";

  "-sgrep", Arg.Set Flag_parsing_cocci.sgrep_mode, 
  "    sgrep mode (sgrep for semantic grep)";
  "-sgrep2", Arg.Set Flag.sgrep_mode2,
  "    sgrep mode2 (sgrep for semantic grep)";
  "-U", Arg.Int (fun n -> Flag_parsing_c.diff_lines := Some (i_to_s n)), 
  "  set number of diff context lines";
  "-partial_match",        Arg.Set Flag_ctl.partial_match, 
  "    report partial matches of the SP on the C file";

  "-iso_file", Arg.Set_string Config.std_iso,   
  " <file> (default=" ^ !Config.std_iso ^")";
  "-macro_file", Arg.Set_string Config.std_h,
  " <file> (default=" ^ !Config.std_h ^ ")";

  "-all_includes",   Arg.Set Flag_cocci.all_includes,
  "  causes all available include files to be used";
  "-I",   Arg.Set_string Flag_cocci.include_path,
  "  <dir> where are the Linux headers (optional)";


  "-dir", Arg.Set dir, 
  "    <dirname> process all files in directory recursively";
  "-kbuild_info", Arg.Set_string kbuild_info, 
  "    <file> improve -dir by grouping related c files";


  "-version",   Arg.Unit (fun () -> 
    pr2 "version: $Date$";
    raise (Common.UnixExit 0)
    ), 
  "   guess what";

  "-shorthelp", Arg.Unit (fun () -> 
    !short_usage_func();
    raise (Common.UnixExit 0)
  ), 
  "    see short list of options";
  "-longhelp", Arg.Unit (fun () -> 
    !long_usage_func();
    raise (Common.UnixExit 0)
    ), 
  "    see all the available options in different categories";
  "-help", Arg.Unit (fun () -> 
    !long_usage_func();
    raise (Common.UnixExit 0)
  ),
  " ";
  "--help", Arg.Unit (fun () -> 
    !long_usage_func();
    raise (Common.UnixExit 0)
  ),
  " ";
    
]

(* the format is a list of triples:
 *  (title of section * (optional) explanation of sections * option list)
 *)
let other_options = [
  "aliases and obsolete options", 
  "",
  [ 
    "-cocci_file", Arg.Set_string cocci_file, 
    "   <file> the semantic patch file";
    "-c", Arg.Set_string cocci_file,     " short option of -cocci_file";
    "-iso", Arg.Set_string Config.std_iso,   " short option of -iso_file";
    "-D",   Arg.Set_string Config.std_h,     " short option of -macro_file";
  ];

  "most useful show options", 
  "",
  [
    "-no_show_diff"           , Arg.Clear Flag_cocci.show_diff, " ";
    "-show_flow"              , Arg.Set Flag_cocci.show_flow,        " ";
    "-no_show_ctl_text"       , Arg.Clear Flag_cocci.show_ctl_text,  " ";
    (* works in conjunction with -show_ctl *)
    "-ctl_inline_let",       Arg.Set Flag_cocci.inline_let_ctl, " ";
    "-ctl_show_mcodekind",   Arg.Set Flag_cocci.show_mcodekind_in_ctl, " ";
    "-show_binding_in_out",  Arg.Set Flag_cocci.show_binding_in_out, " ";
    "-no_show_transinfo",    Arg.Clear Flag_cocci.show_transinfo, " ";
    "-no_show_misc",         Arg.Clear Flag.show_misc, " ";
  ];

  "verbose subsystems options",  
  "",
  [
    "-verbose_ctl_engine",   Arg.Set Flag_ctl.verbose_ctl_engine, " ";
    "-verbose_engine",       Arg.Set Flag_engine.debug_engine,    " ";
    "-no_parse_error_msg", Arg.Clear Flag_parsing_c.verbose_parsing, " ";
    "-no_type_error_msg",  Arg.Clear Flag_parsing_c.verbose_type, " ";
  ];

  "other show options",
  "",
  [
    "-show_c"                 , Arg.Set Flag_cocci.show_c,           " ";
    "-show_cocci"             , Arg.Set Flag_cocci.show_cocci,       " ";
    "-show_before_fixed_flow" , Arg.Set Flag_cocci.show_before_fixed_flow,  " ";
    "-show_ctl_tex"           , Arg.Set Flag_cocci.show_ctl_tex,     " ";
    "-show_SP_julia"       ,    Arg.Set Flag_parsing_cocci.show_SP,  " ";
  ];

  "debug C parsing/unparsing",
  "",
  [
    "-debug_cpp",          Arg.Set  Flag_parsing_c.debug_cpp, " ";
    "-debug_lexer",        Arg.Set  Flag_parsing_c.debug_lexer , " ";
    "-debug_etdt",         Arg.Set  Flag_parsing_c.debug_etdt , "  ";
    "-debug_typedef",      Arg.Set  Flag_parsing_c.debug_typedef, "  ";

    "-filter_msg",      Arg.Set  Flag_parsing_c.filter_msg , 
    "  filter some cpp message when the macro is a \"known\" cpp construct";
    "-filter_define_error",Arg.Set Flag_parsing_c.filter_define_error,"  ";
    "-filter_classic_passed",Arg.Set Flag_parsing_c.filter_classic_passed,"  ";

    "-debug_cfg",          Arg.Set Flag_parsing_c.debug_cfg , "  ";
    "-debug_unparsing",      Arg.Set  Flag_engine.debug_unparsing, "  ";

  ];

  "shortcut for enabling/disabling a set of debugging options at once",
  "",
  [
    (* todo: other profile ? *)
    "-quiet",   Arg.Unit (fun () -> 
      let (set_to_true, set_to_false) = quiet_profile in
      List.iter (fun x -> x := false) set_to_false;
      List.iter (fun x -> x := true) set_to_true;
    ), " ";
  ];

  "bench options",
  "",
  [
    "-profile",          Arg.Set  Common.profile , 
    "   gather timing information about the main coccinelle functions";
    "-bench", Arg.Int (function x -> Flag_ctl.bench := x), 
    "   <level> for profiling the CTL engine";
    "-timeout", Arg.Int (fun x -> Flag_cocci.timeout := Some x), 
    "   <sec> timeout in seconds";
  ];



  "change of algorithm options",
  "", 
  [  
    "-popl", Arg.Set Flag_cocci.popl, 
    "    simplified SmPL, for the popl paper";

    "-loop",              Arg.Set Flag_ctl.loop_in_src_code,    " ";
    "-l1",                Arg.Clear Flag_parsing_c.label_strategy_2, " ";
    "-ifdef",              Arg.Set Flag_parsing_c.ifdef_to_if, 
    "   convert ifdef to if (buggy!)";
    "-noif0_passing",   Arg.Clear Flag_parsing_c.if0_passing, 
    " ";
    "-add_typedef_root",   Arg.Set Flag_parsing_c.add_typedef_root, " ";
    "-disallow_nested_exps", Arg.Set Flag_engine.disallow_nested_exps,
       "disallow an expresion pattern from matching a term and its subterm"
  ];

  "misc options",
  "",
  [
    "-save_tmp_files",   Arg.Set save_tmp_files,   " ";
    "-debugger",         Arg.Set Common.debugger , 
    "   option to set if launch spatch in ocamldebug";
    "-disable_once",     Arg.Set Common._disable_once, 
    "   to print more messages";

    "-use_cache", Arg.Set Flag_parsing_c.use_cache, 
    "   use .ast_raw pre-parsed cached C file";
  ];



  "test mode and test options (works with tests/ or .ok files)",
  "The test options don't work with the -sp_file and so on.",
  [
    "-test",    Arg.Set test_mode, 
    "   <file> launch spatch on tests/file.[c,cocci]";
    "-testall", Arg.Set test_all, 
    "   launch spatch on all files in tests/ having a .res";
    "-test_okfailed", Arg.Set test_okfailed,
    "    generates .{ok,failed,spatch_ok} files using .res files";
    "-test_regression_okfailed", Arg.Set test_regression_okfailed,
    "    process the .{ok,failed,spatch_ok} files in current dir";

    "-compare_with_expected", Arg.Set compare_with_expected, 
    "   use also file.res"; 
    
  ];

  "action mode",
  ("The action options don't work with the -sp_file and so on." ^ "\n" ^
   "It's for the other (internal) uses of the spatch program."
  ),
  [
    (let s = "-tokens_c" in s, Arg.Unit (fun () -> action := s),
    "   <file>");
    (let s = "-parse_c"  in s, Arg.Unit (fun () -> action := s),
    "   <file or dir> works with -dir");
    (let s = "-parse_h"  in s, Arg.Unit (fun () -> action := s),
    "   <file or dir> works with -dir");
    (let s = "-parse_ch"  in s, Arg.Unit (fun () -> action := s),
    "   <file or dir> works with -dir");
    (let s = "-parse_cocci"  in s, Arg.Unit (fun () -> action := s),
    "   <file>");
    (let s = "-show_flow"  in s, Arg.Unit (fun () -> action := s),
    "   <file> or <file:function>");
    (let s = "-control_flow"  in s, Arg.Unit (fun () -> action := s),
    "   <file> or <file:function>");
    (let s = "-parse_unparse"  in s, Arg.Unit (fun () -> action := s),
    "   <file>");
    (let s = "-typeur"  in s, Arg.Unit (fun () -> action := s),
    "   <file>");
    (let s = "-compare_c"  in s, Arg.Unit (fun () -> action := s),
    "  <file1> <file2>");
    (let s = "-xxx"  in s, Arg.Unit (fun () -> action := s),
    "  ");
  ];
]


let all_options = 
  short_options ++ List.concat (List.map Common.thd3 other_options)
 

(* I don't want the -help and --help that are appended by Arg.align *)
let arg_align2 xs =
  Arg.align xs +> List.rev +> Common.drop 2 +> List.rev

(* copy paste of Arg.parse. Don't want the default -help msg *)
let arg_parse2 l f msg =
  (try
    Arg.parse_argv Sys.argv l f msg;
  with
  | Arg.Bad msg -> (* eprintf "%s" msg; exit 2; *)
      let xs = Common.lines msg in
      (* take only head, it's where the error msg is *)
      pr2 (List.hd xs);
      !short_usage_func();
      raise (Common.UnixExit (2))
  | Arg.Help msg -> (* printf "%s" msg; exit 0; *)
      raise Impossible  (* -help is specified in speclist *)
  )
  

let short_usage () =
 begin
  Arg.usage (Arg.align short_options) usage_msg; 
  pr2 "";
  pr2 "Example of use:";
  pr2 "  ./spatch -sp_file foo.cocci foo.c -o /tmp/newfoo.c";
  pr2 "";
 end

let long_usage () = 
 begin
  pr usage_msg;
  pr "";
  (("main options", "", short_options)::other_options) +> List.iter 
    (fun (title, explanations, xs) -> 
      pr title;
      pr_xxxxxxxxxxxxxxxxx();
      if explanations <> "" 
      then begin pr explanations; pr "" end;
      arg_align2 xs +> List.iter (fun (key,action,s) -> pr ("  " ^ key ^ s));
      pr "";
    );
 end
      

let _ = short_usage_func := short_usage
let _ = long_usage_func := long_usage



  
(*****************************************************************************)
(* The coccinelle main entry point *)
(*****************************************************************************)
let main () = 
  begin
    let args = ref [] in

    arg_parse2 (Arg.align all_options) (fun x -> args := x::!args) usage_msg;
    args := List.rev !args;

    if !cocci_file <> "" && (not (!cocci_file =~ ".*\\.\\(sgrep\\|spatch\\)$"))
    then cocci_file := Common.adjust_ext_if_needed !cocci_file ".cocci";

    if !Config.std_iso <> "" 
    then Config.std_iso := Common.adjust_ext_if_needed !Config.std_iso ".iso";
    if !Config.std_h <> "" 
    then Config.std_h := Common.adjust_ext_if_needed !Config.std_h ".h";

    if !Config.std_h <> "" 
    then 
      if not (Common.lfile_exists !Config.std_h)
      then pr2 ("warning: Can't find default macro file: " ^ !Config.std_h)
      else 
        Parsing_hacks._defs := Common.hash_of_list
          (Parse_c.parse_cpp_define_file !Config.std_h)
    ;

    (* must be done after Arg.parse, because Common.profile is set by it *)
    Common.profile_code "Main total" (fun () -> 

    (match (!args) with

    (* --------------------------------------------------------- *)
    (* The test framework. Works with tests/ or .ok and .failed  *)
    (* --------------------------------------------------------- *)
    | [x] when !test_mode    -> 
        Flag_cocci.include_path := "tests/include";
        Testing.testone x !compare_with_expected

    | []  when !test_all -> 
        Flag_cocci.include_path := "tests/include";
        Testing.testall ()

    | [] when !test_regression_okfailed -> 
        Testing.test_regression_okfailed ()

    | x::xs when !test_okfailed -> 
        (* do its own timeout on Flag_cocci.timeout internally *)
        Testing.test_okfailed !cocci_file (x::xs)

    (* --------------------------------------------------------- *)
    (* Actions, useful to debug subpart of coccinelle *)
    (* --------------------------------------------------------- *)
    | [file] when !action = "-tokens_c" -> 
        Testing.test_tokens_c file
    | x::xs when  !action = "-parse_c" -> 
        Testing.test_parse_c  (x::xs) !dir 
    | x::xs when  !action = "-parse_h" -> 
        Testing.test_parse_h  (x::xs) !dir 
    | x::xs when  !action = "-parse_ch" -> 
        Testing.test_parse_ch  (x::xs) !dir 
    | [file] when !action = "-parse_cocci" -> 
        Testing.test_parse_cocci file
    | [filefunc] when !action = "-control_flow" || !action = "-show_flow" -> 
        Testing.test_cfg filefunc
    | [file] when !action = "-parse_unparse" -> 
       Testing.test_parse_unparse file
    | [file] when !action = "-typeur" -> 
        Testing.test_typeur file
    | [file1;file2] when !action = "-compare_c" -> 
       Testing.test_compare_c file1 file2 (* result is in unix code *)
    | [] when !action = "-compare_c_hardcoded" -> 
        Testing.test_compare_c_hardcoded ()
    | xs when !action = "-xxx" -> 
        Testing.test_xxx xs !dir

    (* --------------------------------------------------------- *)
    (* This is the main entry *)
    (* --------------------------------------------------------- *)
    | x::xs -> 

        if (!cocci_file = "") 
        then failwith "I need a cocci file,  use -sp_file <file>";

        let infiles = 
          Common.profile_code "Main.infiles computation" (fun () -> 
          match !dir, !kbuild_info with
          | false, _ -> [x::xs]
          | true, "" -> 
              Common.cmd_to_list ("find "^(join " " (x::xs))^" -name \"*.c\"")
              +> List.map (fun x -> [x])
          | true, kbuild_info_file -> 
              let dirs = 
                Common.cmd_to_list ("find "^(join " " (x::xs))^" -type d") in
              let info = Kbuild.parse_kbuild_info kbuild_info_file in
              let groups = Kbuild.files_in_dirs dirs info in

              groups +> List.map (function Kbuild.Group xs -> xs)
          )
        in

        let outfiles = 
          Common.profile_code "Main.outfiles computation" (fun () -> 
          infiles +> List.map (fun cfiles -> 
            pr2 ("HANDLING: " ^ (join " " cfiles));
            Common.timeout_function_opt !Flag_cocci.timeout (fun () -> 
            Common.report_if_take_time 10 (join " " cfiles) (fun () -> 
            (* Unix.sleep 1; *)
            (try Cocci.full_engine (!cocci_file, !Config.std_iso) cfiles
              with 
              | Common.UnixExit x -> raise (Common.UnixExit x)
              | e -> 
                  if !dir then begin
                    pr2 ("EXN:" ^ Printexc.to_string e); 
                    [] (* *)
                  end 
                  else raise e
            ))))
          +> List.concat
          )
        in
        Common.profile_code "Main.result analysis" (fun () -> 

	  Ctlcocci_integration.print_bench();

          let outfiles = Cocci.check_duplicate_modif outfiles in
          
          outfiles +> List.iter (fun (infile, outopt) -> 
            outopt +> do_option (fun outfile -> 
              if !inplace_modif
              then begin
                Common.command2 ("cp " ^infile ^ " " ^ infile ^ ".cocci_orig");
                Common.command2 ("cp " ^ outfile ^ " " ^ infile);
              end;
              if !outplace_modif
              then Common.command2 ("cp " ^outfile^ " " ^infile ^".cocci_res");

              if !output_file = "" 
              then begin
                let tmpfile = "/tmp/"^Common.basename infile in
                pr2 (sprintf "One file modified. Result is here: %s" tmpfile);
                Common.command2 ("cp "^outfile^" "^tmpfile);
              end

            ));
          if !output_file <> "" then
            (match outfiles with 
            | [infile, Some outfile] when infile = x && null xs -> 
                Common.command2 ("cp " ^outfile^ " " ^ !output_file);
            | [infile, None] when infile = x && null xs -> 
                Common.command2 ("cp " ^infile^ " " ^ !output_file);
            | _ -> 
                failwith 
                  ("-o can not be applied because there is multiple " ^
                      "modified files");
            );
          
          if !compare_with_expected
          then Testing.compare_with_expected outfiles
        )

    (* --------------------------------------------------------- *)
    (* empty entry *)
    (* --------------------------------------------------------- *)
    | [] -> short_usage()
        
  ));
  end

(*****************************************************************************)
let _ =
  if not (!Sys.interactive) then 
    Common.exn_to_real_unixexit (fun () -> 

      Sys.set_signal Sys.sigint (Sys.Signal_handle   (fun _ -> 
        pr2 "C-c intercepted, will do some cleaning before exiting";
        (* But if do some try ... with e -> and if do not reraise the exn,
         * the bubble never goes at top and so I cant really C-c.
         * 
         * A solution would be to not raise, but do the erase_temp_file in the
         * syshandler, here, and then exit.
         * The current solution is to not do some wild  try ... with e
         * by having in the exn handler a case: UnixExit x -> raise ... | e ->
         *)
        Sys.set_signal Sys.sigint Sys.Signal_default;
        raise (Common.UnixExit (-1))
      ));

      (* The finalize below makes it tedious to go back to exn when use
       * 'back' in the debugger. Hence this special case. But the 
       * Common.debugger will be set in main(), so too late, so 
       * have to be quicker
       *)
      if Sys.argv +> Array.to_list +> List.exists (fun x -> x ="-debugger")
      then Common.debugger := true;

      Common.finalize          (fun ()-> 
        Common.pp_do_in_zero_box (fun () -> 
          main ();
          Ctlcocci_integration.print_bench();
        ))
       (fun()-> 
         Common.profile_diagnostic ();
         if not !save_tmp_files then Common.erase_temp_files ();
       )
    )
      
