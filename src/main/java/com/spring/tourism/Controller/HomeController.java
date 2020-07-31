package com.spring.tourism.Controller;

import com.spring.tourism.Entity.*;
import com.spring.tourism.Repository.*;
import com.spring.tourism.RowMapper.TravelSimpleRowMapper;
import com.spring.tourism.RowMapper.TravelStokeMapper;
import com.spring.tourism.Support.SHA512;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;

import javax.annotation.Resource;
import javax.servlet.http.Cookie;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.*;

@Controller
public class HomeController {
    private static final int SIZE = 30;

    @Resource
    private JdbcTemplate jdbcTemplate;

    private final RaiderEntityRepository raiderEntityRepository;

    private final RaiderDetailRepository raiderDetailRepository;

    private final TravelProductRepository travelProductRepository;

    private final TravelStokeRepository travelStokeRepository;

    private final UserRepository userRepository;

    private final UserImageRepository userImageRepository;

    @Autowired
    public HomeController(UserRepository userRepository,
                          TravelStokeRepository travelStokeRepository,
                          TravelProductRepository travelProductRepository,
                          RaiderEntityRepository raiderEntityRepository,
                          RaiderDetailRepository raiderDetailRepository,
                          UserImageRepository userImageRepository) {
        this.userRepository = userRepository;
        this.travelStokeRepository = travelStokeRepository;
        this.travelProductRepository = travelProductRepository;
        this.raiderEntityRepository = raiderEntityRepository;
        this.raiderDetailRepository = raiderDetailRepository;
        this.userImageRepository = userImageRepository;
    }

    // 初始界面
    @GetMapping(path = "/index")
    public String home() {
        return "index";
    }

    // 初始的注册界面
    @GetMapping(path = "/login")
    public String loginForm(Model model,
                            @CookieValue(value = "userId", defaultValue = "") String userId) {
        if (userId == null || userId.trim().length() == 0) {
            model.addAttribute("user", new UserFormEntity());
            return "login";
        } else {
            return "redirect:/tourism";
        }
    }

    // 处理登录表单处理数据
    @PostMapping(path = "/login")
    public String loginSubmit(@ModelAttribute UserFormEntity userFormEntity,
                              HttpServletResponse response) {
        String password = new SHA512().encryptThisString(userFormEntity.getUserPassword());
        userFormEntity.setUserPassword(password);
        UserEntity userEntity = userRepository.
                getUserEntityByUserIdAndUserPassword(userFormEntity.getUserId(),
                        userFormEntity.getUserPassword());
        if (userEntity != null) {
            // 生成Cookie对象， 保存在客户端浏览器中
            Cookie cookie = new Cookie("userId", userFormEntity.getUserId());
            cookie.setMaxAge(7 * 24 * 60 * 60);
            cookie.setSecure(false);
            cookie.setHttpOnly(true);
            cookie.setPath("/");
            response.addCookie(cookie);

            return "redirect:/tourism";
        } else {
            return "error";
        }
    }

    @GetMapping(path = "/loginWithCode")
    public String loginWithCode(Model model) {
        model.addAttribute("user", new UserLoginWithCode());
        return "loginWithCode";
    }

    @PostMapping(path = "/loginWithCode")
    public String loginWithCodeSubmit(@ModelAttribute UserLoginWithCode userLoginWithCode,
                                      HttpServletResponse response) {
        try {
            UserEntity userEntity = userRepository.getUserEntityByUserId(userLoginWithCode.getUserId());
            if (userLoginWithCode.getRemember()) {
                Cookie cookie = new Cookie("userId", userLoginWithCode.getUserId());
                cookie.setMaxAge(7 * 24 * 60 * 60);
                cookie.setSecure(false);
                cookie.setHttpOnly(true);
                cookie.setPath("/");
                response.addCookie(cookie);
            }

            return "tourism";
        } catch (Exception e) {
            return "error";
        }
    }

    // 用户注册的初始界面
    @GetMapping(path = "/register")
    public String register() {
        return "register";
    }

    // 处理用户注册信息
    @PostMapping(path = "/register")
    public String registerSubmit() {
        return "register";
    }

    // 忘记密码的初始界面地址
    @GetMapping(path = "/forgetPassword")
    public String forgetPassword() {
        return "forgetPassword";
    }

    // 设置密码的初始界面， 要求必须有用户的id
    @GetMapping(path = "/setPassword")
    public String setPassword(Model model,
                              String userId,
                              String userName) {
        if (userId == null || userId.trim().length() == 0) {
            return "error";
        }

        if (userName == null || userName.trim().length() == 0) {
            return "error";
        }

        UserEntity obj = new UserEntity();
        obj.setUserId(userId);
        obj.setUserName(userName);
        model.addAttribute("userEntity", obj);
        return "setPassword";
    }

    @PostMapping(path = "/setPassword")
    public String setPasswordSubmit(@ModelAttribute UserEntity userEntity) {
        try {
            SHA512 sha512 = new SHA512();
            String password = sha512.encryptThisString(userEntity.getUserPassword());
            userEntity.setUserPassword(password);
            userRepository.save(userEntity);

            UserImageEntity userImageEntity = new UserImageEntity();
            userImageEntity.setUserId(userEntity.getUserId());
            userImageEntity.setImageAddress("/images/backgrund-1.jpg");

            userImageRepository.save(userImageEntity);

            return "redirect:/registerLogin";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/registerLogin")
    public String registerLogin(Model model) {
        model.addAttribute("user", new UserFormEntity());
        return "login";
    }

    @GetMapping(path = "/helpCenter")
    public String helpCenter() {
        return "helpCenter";
    }

    @GetMapping(path = "/myComment")
    public String myComment(Model model,
                            @CookieValue(value = "userId") String userId) {
        try {
            if (userId == null || userId.trim().length() == 0) {
                return "error";
            }

            List<RaiderEntity> raiderEntities =
                    raiderEntityRepository.getCommentRaiderEntitiesByUserId(userId);

            model.addAttribute("userCommentRaiderEntities", raiderEntities);
            return "myComment";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/myCommentDetail")
    public String myCommentDetail(Model model, @NonNull String raiderId,
                                  @CookieValue(value = "userId") String userId) {
        try {
            if (raiderId.trim().length() == 0) {
                return "error";
            }

            if (userId == null || userId.trim().length() == 0) {
                return "error";
            }

            RaiderCommentImpl raiderComment = new RaiderCommentImpl(jdbcTemplate);

            List<RaiderCommentEntity> raiderCommentEntityList
                    = raiderComment.getRaiderCommentByRaiderIdAndUserId(raiderId, userId);

            model.addAttribute("raiderCommentEntities", raiderCommentEntityList);

            return "myCommentDetail";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/removeRaiderComment")
    public void removeRaiderComment(HttpServletResponse response,
                                    @NonNull String raiderId, @NonNull Integer commentId,
                                    @CookieValue(value = "userId") String userId) throws IOException {
        try (PrintWriter printWriter = response.getWriter()) {
            if (raiderId.trim().length() == 0) {
                printWriter.write("0");
            }

            if (commentId <= Integer.MIN_VALUE || commentId >= Integer.MAX_VALUE) {
                printWriter.write("0");
            }

            if (userId == null || userId.trim().length() == 0) {
                printWriter.write("0");
            }

            RaiderCommentImpl raiderComment = new RaiderCommentImpl(jdbcTemplate);
            raiderComment.removeRaiderCommentByRaiderIdAndUserIdAndCommentId(raiderId, userId, commentId);

            printWriter.write("1");
        } catch (Exception e) {
            response.getWriter().write("1");
        }
    }

    @GetMapping(path = "/myInfo")
    public String myInfo(@CookieValue(value = "userId") String userId,
                         Model model) {
        try {
            UserEntity userEntity = userRepository.getUserEntityByUserId(userId);
            UserImageEntity userImageEntity =
                    userImageRepository.getUserImageEntityByUserId(userId);

            if (userEntity == null) {
                UserImageEntity userImageEntity1 = new UserImageEntity();
                userImageEntity1.setUserId(userId);
                userImageEntity1.setImageAddress("/images/backgrund-1.jpg");
                model.addAttribute("userImage", userImageEntity1);
            } else {
                model.addAttribute("userImage", userImageEntity);
            }

            model.addAttribute("userEntity", userEntity);
            return "myInfo";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/myOrders")
    public String myOrders(Model model,
                           Integer placeholder,
                           @CookieValue(value = "userId") String userId) {
        try {
            TravelOrderImpl travelOrder = new TravelOrderImpl(jdbcTemplate);
            List<TravelOrder> travelOrders = new ArrayList<>();

            if (placeholder == 2) {
                travelOrders = travelOrder.getWillTravelOrders(userId);
            } else if (placeholder == 3) {
                travelOrders = travelOrder.getHasTravelOrders(userId);
            } else if (placeholder == 4) {
                travelOrders = travelOrder.getAllSaveTravelOrders(userId);
            } else {
                travelOrders = travelOrder.getAllTravelOrders(userId);
            }

            model.addAttribute("travelOrders", travelOrders);

            return "myOrders";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/myRaider")
    public String myRaider(Model model,
                           @CookieValue(value = "userId") String userId) {
        try {
            List<RaiderEntity> raiderEntities =
                    raiderEntityRepository.getRaiderEntitiesByUserId(userId);

            model.addAttribute("userRaiders", raiderEntities);
            return "myRaider";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/mySave")
    public String mySave(Model model,
                         @CookieValue(value = "userId") String userId) {
        try {
            if (userId == null || userId.trim().length() == 0) {
                return "error";
            }

            List<RaiderEntity> raiderEntities =
                    raiderEntityRepository.getSaveRaiderEntitiesByUserId(userId);

            model.addAttribute("raiderEntities", raiderEntities);
            return "mySave";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/myStarRaider")
    public String myStarRaider(Model model,
                               @CookieValue(value = "userId") String userId) {
        try {
            if (userId == null || userId.trim().length() == 0) {
                return "error";
            }

            List<RaiderEntity> raiderEntities =
                    raiderEntityRepository.getStarRaiderEntityByUserId(userId);

            model.addAttribute("raiderEntities", raiderEntities);
            return "myStarRaider";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/raider")
    public String raider(Model model) {
        try {
            List<RaiderEntity> raiderEntities =
                    raiderEntityRepository.getRaiderEntityByStartAndEnd(SIZE, 0);

            model.addAttribute("raiders", raiderEntities);
            return "raider";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/raiderDetail")
    public String raiderDetail() {
        return "raiderDetail";
    }

    @GetMapping(path = "/tourism")
    public String tourism() {
        return "tourism";
    }

    @GetMapping(path = "/travel")
    public String travel(Model model) {
        try {
            String sql = "SELECT id AS travel_id, title AS travel_title, score AS travel_score,\n" +
                    "       price AS travel_price, visit_num AS num_people,\n" +
                    "       start_date AS travel_date, kind AS kind_name, imageAddress AS image_address\n" +
                    "FROM get_travel_simple() LIMIT ? OFFSET ?";

            TravelSimpleImpl travelSimple = new TravelSimpleImpl();
            List<TravelSimpleEntity> travelSimpleEntities =
                    jdbcTemplate.query(sql, new Object[]{SIZE, 0},
                            new TravelSimpleRowMapper());
//            System.out.println("travel simple size: " + travelSimpleEntities.size());
            model.addAttribute("travelSimpleList", travelSimpleEntities);
            return "travel";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/travelDetail")
    public String travelDetail(Model model, String travelId) {
        if (travelId == null || travelId.trim().length() == 0) {
            return "error";
        }

        try {
            String sql = "SELECT * FROM (\n" +
                    "\tSELECT * FROM travel_stoke WHERE travel_id=? \n" +
                    "\tORDER BY travel_step_id) AS temp";

            List<TravelStokeEntity> travelStokeEntityList =
                    jdbcTemplate.query(sql, new Object[]{travelId}, new TravelStokeMapper());
            travelStokeEntityList.remove(travelStokeEntityList.size() - 1);

            TravelProductEntity travelProductEntity =
                    travelProductRepository.getTravelProductEntityByTravelId(travelId);

            Map<Short, List<Map<Short, String>>> travelStokeMap = new HashMap<>();

            for (TravelStokeEntity travelStokeEntity : travelStokeEntityList) {
                Map<Short, String> stokeMap = new HashMap<>();
//                System.out.println(travelStokeEntity.toString());
                stokeMap.put(travelStokeEntity.getTravelCopyId(),
                        travelStokeEntity.getTravelStepDetail().replaceAll("<br>", "\n"));

                if (!travelStokeMap.containsKey(travelStokeEntity.getTravelStepId())) {
                    List<Map<Short, String>> mapList = new ArrayList<>();
                    mapList.add(stokeMap);

                    travelStokeMap.put(travelStokeEntity.getTravelStepId(), mapList);
                } else {
                    travelStokeMap.get(travelStokeEntity.getTravelStepId()).add(stokeMap);
                }
            }

            TreeMap<Short, List<Map<Short, String>>> sorted = new TreeMap<>(travelStokeMap);

            model.addAttribute("travelStoke", sorted);
            model.addAttribute("travelProduct", travelProductEntity);
            return "travelSchedule";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/travelSchedule")
    public String travelSchedule() {
        return "travelSchedule";
    }
}
