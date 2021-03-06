(* Copyright 2015 Kestrel Institute. See file LICENSE for license details *)


(* FIXME HERE: document this! It is somewhat like Oleg's finally tagless
interpreters *)

C_DSL qualifying spec
  import C

  (* Expression combinators, which have type Monad Value *)

  (* Embedding an already-translated expression into a computation *)
  op EMBEDEXPR_m (e:Expression) : Monad C.Value =
    evaluate e

  (* Variables *)
  op VAR_m (id:Identifier) : Monad C.Value =
    lookupIdentifierValue id

  (* Integer constants *)
  op ICONST_m (str : IntegerConstant) : Monad C.Value =
    evaluateIntegerConstant str

  (* Unary operators *)
  type Operator1 = Monad C.ExpressionValue -> Monad C.ExpressionValue
  op liftOperator1 (f : C.ExpressionValue -> Monad C.ExpressionValue) : Operator1 =
    fn m -> {val <- m; f val}

  op STAR_m : Operator1 = liftOperator1 readPtrValue
  op PLUS_m : Operator1 = liftOperator1 operator_PLUS
  op MINUS_m : Operator1 = liftOperator1 operator_MINUS
  op NOT_m : Operator1 = liftOperator1 operator_NOT
  op NEG_m : Operator1 = liftOperator1 operator_NEG

  (* FIXME HERE: write correctness theorems for UNARYOP_m and BINARYOP_m *)
  op UNARYOP_m (uop: UnaryOp) : Operator1 = evaluatorForUnaryOp uop

  (* Binary operators *)
  type Operator2 = Monad C.ExpressionValue * Monad C.ExpressionValue ->
                   Monad C.ExpressionValue
  op liftOperator2 (f : C.ExpressionValue * C.ExpressionValue ->
                      Monad C.ExpressionValue) : Operator2 =
    fn (m1,m2) -> {val1 <- m1; val2 <- m2; f (val1, val2)}

  op MUL_m : Operator2 = liftOperator2 operator_MUL
  op DIV_m : Operator2 = liftOperator2 operator_DIV
  op REM_m : Operator2 = liftOperator2 operator_REM
  op ADD_m : Operator2 = liftOperator2 operator_ADD
  op SUB_m : Operator2 = liftOperator2 operator_SUB
  op SHL_m : Operator2 = liftOperator2 operator_SHL
  op SHR_m : Operator2 = liftOperator2 operator_SHR
  op LT_m : Operator2 = liftOperator2 operator_LT
  op GT_m : Operator2 = liftOperator2 operator_GT
  op LE_m : Operator2 = liftOperator2 operator_LE
  op GE_m : Operator2 = liftOperator2 operator_GE
  op EQ_m : Operator2 = liftOperator2 operator_EQ
  op NE_m : Operator2 = liftOperator2 operator_NE
  op AND_m : Operator2 = liftOperator2 operator_AND
  op XOR_m : Operator2 = liftOperator2 operator_XOR
  op IOR_m : Operator2 = liftOperator2 operator_IOR

  op LAND_m : Operator2 = operator_LAND
  op LOR_m : Operator2 = operator_LOR

  op BINARYOP_m (bop: BinaryOp) : Operator2 = evaluatorForBinaryOp bop

  (* Array subscripting *)
  op SUBSCRIPT_m : Operator2 = fn (m1,m2) -> STAR_m (ADD_m (m1,m2))

  (* Struct member access *)
  op MEMBER_m (e: Monad Value, mem: Identifier) : Monad Value =
    {v <- e;
     accessStructValueMember (v, mem)}

  op MEMBERP_m (e: Monad Value, mem: Identifier) : Monad Value =
    {v <- e;
     res <- dereferencePointer v;
     res' <- accessStructLValueMember (res, mem);
     lvalueConversion res'}


  (* LValue combinators, which have type Monad LValueRes *)

  op LVAR_m (id:Identifier) : Monad LValueResult = lookupIdentifier id

  op ADDR_m (e : Monad LValueResult) : Monad C.Value =
    {res <- e; return (V_pointer res)}

  op LSTAR_m (m : Monad C.Value) : Monad LValueResult =
    {val <- m; dereferencePointer val}

  (* Array subscripting *)
  op LSUBSCRIPT_m (arr : Monad C.Value, ind : Monad C.Value) : Monad LValueResult =
    LSTAR_m (ADD_m (arr, ind))

  (* Struct member access *)
  op LMEMBER_m (e: Monad LValueResult, mem: Identifier) : Monad LValueResult =
    {res <- e;
     accessStructLValueMember (res, mem)}

  op LMEMBERP_m (e: Monad Value, mem: Identifier) : Monad LValueResult =
    {v <- e;
     res' <- dereferencePointer v;
     accessStructLValueMember (res', mem)}


  (* Statement combinators, which have type Monad () *)

  (* Assignment, which takes expressions lhs and rhs and performs *lhs = rhs *)
  op ASSIGN_m (lhs : Monad LValueResult, rhs : Monad C.Value) : Monad () =
    {res <- lhs; rhs_val <- rhs;
     assignValue (res, rhs_val)}

  (* Return statements *)
  op RETURN_m (expr : Monad C.Value) : Monad () =
    {v <- expr; returnFromFun (Some v)}
  op RETURN_VOID_m : Monad () = returnFromFun None

  (* If-then-else statements *)
  op IFTHENELSE_m (expr : Monad C.Value,
                   then_branch : Monad (), else_branch : Monad ()) : Monad () =
    {condition <- expr;
     isZero <- zeroScalarValue? condition;
     if ~ isZero then then_branch else else_branch}

  (* While statements *)
  op WHILE_m (expr : Monad C.Value, body : Monad ()) : Monad () =
    mfix (fn recurse -> fn unit ->
          {condition <- expr;
           isZero <- zeroScalarValue? condition;
           if isZero then return () else
             {_ <- body; recurse ()}}) ()

  (* Blocks: BLOCK_m_helper sequences all the statements / declarations, and
  BLOCK_m adds the fresh local scope around them *)
  op BLOCK_m_helper (body: List (Monad ())) : Monad () =
    {_ <- mapM id body; return ()}
  op BLOCK_m (body: List (Monad ())) : Monad () =
    withFreshLocalBindings empty (BLOCK_m_helper body)

  (* STMT_m marks statements (as opposed to variable declarations) inside a block *)
  op STMT_m (m: Monad ()) : Monad () =
    m

  (* Variable declarations *)
  op VARDECL_m (tp_name: TypeName, id: Identifier) : Monad () =
    {tp <- expandTypeNameM tp_name;
     addLocalBinding (id, V_undefined tp)}

  (* External declarations, which have type XUMonad () *)
  type ExtDecl = XUMonad ()

  (* Function combinator *)
  op FUNCTION_m (retTypeName : C.TypeName, name : Identifier,
                 paramDecls : ParameterList,
                 body : Monad ()) : ExtDecl =
    {retType <- expandTypeNameXU retTypeName;
     params <- mapM_XU evalParameterDeclaration paramDecls;
     setFunType (name, (retType, (unzip params).2));
     xenv <- xu_get;
     let f = makeCFunction (retType, params,
                            localR (fn r -> makeGlobalR (xenv, r.r_functions))
                              body) in
     xu_emit (name, ObjFile_Function (f, (retType, (unzip params).2)))}


  (*** Theorems ***)

  (** Expressions **)

  theorem EMBEDEXPR_m_correct is
    fa (expr,expr') expr = expr' => evaluate expr = EMBEDEXPR_m expr'

  theorem VAR_m_correct is
    fa (id,e) e = E_lvalue (LV_ident id) => evaluate e = VAR_m id

  theorem ICONST_m_correct is
    fa (str,e)
      e = E_strict (E_const str) =>
      evaluate e = ICONST_m str

  (* Unary operators *)

  theorem STAR_m_correct is
    fa (e1,rv1,e)
      e = E_lvalue (LV_star e1) && evaluate e1 = rv1
      =>
      evaluate e = STAR_m rv1

  theorem PLUS_m_correct is
    fa (e1,rv1,e)
      e = E_strict (E_unary (UOp_PLUS, e1)) && evaluate e1 = rv1
      =>
      evaluate e = PLUS_m rv1

  theorem MINUS_m_correct is
    fa (e1,rv1,e)
      e = E_strict (E_unary (UOp_MINUS, e1)) && evaluate e1 = rv1
      =>
      evaluate e = MINUS_m rv1

  theorem NOT_m_correct is
    fa (e1,rv1,e)
      e = E_strict (E_unary (UOp_NOT, e1)) && evaluate e1 = rv1
      =>
      evaluate e = NOT_m rv1

  theorem NEG_m_correct is
    fa (e1,rv1,e)
      e = E_strict (E_unary (UOp_NEG, e1)) && evaluate e1 = rv1
      =>
      evaluate e = NEG_m rv1

  (* Binary operators *)

  theorem MUL_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_MUL, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = MUL_m (rv1, rv2)

  theorem DIV_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_DIV, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = DIV_m (rv1, rv2)

  theorem REM_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_REM, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = REM_m (rv1, rv2)

  theorem ADD_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_ADD, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = ADD_m (rv1, rv2)

  theorem SUB_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_SUB, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = SUB_m (rv1, rv2)

  theorem SHL_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_SHL, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = SHL_m (rv1, rv2)

  theorem SHR_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_SHR, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = SHR_m (rv1, rv2)

  theorem LT_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_LT, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = LT_m (rv1, rv2)

  theorem GT_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_GT, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = GT_m (rv1, rv2)

  theorem LE_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_LE, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = LE_m (rv1, rv2)

  theorem GE_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_GE, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = GE_m (rv1, rv2)

  theorem EQ_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_EQ, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = EQ_m (rv1, rv2)

  theorem NE_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_NE, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = NE_m (rv1, rv2)

  theorem AND_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_AND, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = AND_m (rv1, rv2)

  theorem XOR_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_XOR, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = XOR_m (rv1, rv2)

  theorem IOR_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_IOR, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = IOR_m (rv1, rv2)

  theorem LAND_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_LAND, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = LAND_m (rv1, rv2)

  theorem LOR_m_correct is
    fa (e1,e2,rv1,rv2,e)
      e = E_strict (E_binary (e1, BinOp_LOR, e2)) &&
      evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = LOR_m (rv1, rv2)

  (* Array subscripts *)
  theorem SUBSCRIPT_m_correct is
    fa (e1,e2,e,rv1,rv2)
      e = E_lvalue (LV_subscript (e1, e2)) && evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluate e = SUBSCRIPT_m (rv1, rv2)

  theorem MEMBER_m_correct is
    fa (e1,mem,e,rv1)
      e = E_strict (E_member (e1, mem)) && evaluateStrictExpr e1 = rv1
      =>
      evaluate e = MEMBER_m (rv1, mem)

  theorem MEMBERP_m_correct is
    fa (e1,mem,e,rv1)
      e = E_lvalue (LV_memberp (e1, mem)) && evaluate e1 = rv1
      =>
      evaluate e = MEMBERP_m (rv1, mem)


  (** LValues **)

  theorem LVAR_m_correct is
    fa (id,lv)
      lv = LV_ident id => evaluateLValue lv = LVAR_m id

  theorem ADDR_m_correct is
    fa (lv1,res1,e)
      e = E_strict (E_addr lv1) && evaluateLValue lv1 = res1
      =>
      evaluate e = ADDR_m res1

  theorem LSTAR_m_correct is
    fa (e1,rv1,e)
      e = LV_star e1 && evaluate e1 = rv1
      =>
      evaluateLValue e = LSTAR_m rv1

  theorem LSUBSCRIPT_m_correct is
    fa (e1,e2,expr,rv1,rv2)
      expr = LV_subscript (e1, e2) && evaluate e1 = rv1 && evaluate e2 = rv2
      =>
      evaluateLValue expr = LSUBSCRIPT_m (rv1, rv2)

  theorem LMEMBER_m_correct is
    fa (lv1,mem,expr,res1)
      expr = LV_member (lv1, mem) && evaluateLValue lv1 = res1
      =>
      evaluateLValue expr = LMEMBER_m (res1, mem)

  theorem LMEMBERP_m_correct is
    fa (e1,mem,expr,rv1)
      expr = LV_memberp (e1, mem) && evaluate e1 = rv1
      =>
      evaluateLValue expr = LMEMBERP_m (rv1, mem)


  (** Statements **)

  theorem ASSIGN_m_correct is
    fa (e1,e2,stmt,lv,rv)
      stmt = S_assign (e1, e2) && evaluateLValue e1 = lv && evaluate e2 = rv
      =>
      evalStatement stmt = ASSIGN_m (lv, rv)

  theorem RETURN_m_correct is
    fa (e,stmt,rv)
      stmt = S_return (Some e) && evaluate e = rv
      =>
      evalStatement stmt = RETURN_m rv

  theorem RETURN_VOID_m_correct is
    fa (stmt)
      stmt = S_return None
      =>
      evalStatement stmt = RETURN_VOID_m

  theorem IFTHENELSE_m_correct is
    fa (e,s1,s2,rv,m1,m2,stmt)
      stmt = S_if (e, s1, Some s2) && evaluate e = rv &&
      evalStatement s1 = m1 && evalStatement s2 = m2
      =>
      evalStatement stmt = IFTHENELSE_m (rv, m1, m2)

  theorem WHILE_m_correct is
    fa (e,body,rv,m,stmt)
      stmt = S_while (e, body) && evaluate e = rv && evalStatement body = m
      =>
      evalStatement stmt = WHILE_m (rv, m)

  theorem BLOCK_m_correct is
    fa (mods,stmt,blockitems)
      stmt = S_block blockitems &&
      evalBlockItems blockitems = BLOCK_m_helper mods
      =>
      evalStatement stmt = BLOCK_m mods

  theorem BLOCK_m_helper_correct_nil is
    fa (blockitems)
      blockitems = [] =>
      evalBlockItems blockitems = BLOCK_m_helper []

  theorem BLOCK_m_helper_correct_cons_stmt is
    fa (blockitems,m,mods,stmt,blockitems')
      blockitems = BlockItem_statement stmt::blockitems' &&
      evalStatement stmt = m &&
      evalBlockItems blockitems' = BLOCK_m_helper mods =>
      evalBlockItems blockitems = BLOCK_m_helper (STMT_m m :: mods)

  theorem BLOCK_m_correct_cons_decl is
    fa (blockitems,tp,id,mods,blockitems')
      blockitems = BlockItem_declaration (tp,id)::blockitems' &&
      evalBlockItems blockitems' = BLOCK_m_helper mods =>
      evalBlockItems blockitems = BLOCK_m_helper (VARDECL_m (tp,id) :: mods)

  (* External Declarations *)
  theorem FUNCTION_m_correct is
    fa (retTypeName, name, params, body, d, m)
      d = XU_function {FDef_retType  = retTypeName,
                       FDef_name     = name,
                       FDef_params   = params,
                       FDef_body     = Some body,
                       FDef_isExtern = false}
      && evalStatement body = m
      =>
      evalTranslationUnitElem d = FUNCTION_m (retTypeName, name, params, m)

end-spec
