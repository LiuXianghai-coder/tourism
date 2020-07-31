package com.spring.tourism.Controller;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.internal.bind.SqlDateTypeAdapter;
import com.google.gson.reflect.TypeToken;
import com.spring.tourism.Entity.*;
import com.spring.tourism.Repository.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;

import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

@Controller
@RequestMapping(path = "/raiderController")
public class RaiderController {
    private final RaiderDetailRepository raiderDetailRepository;

    private final RaiderEntityRepository raiderEntityRepository;

    private final UserSaveRaiderRepository userSaveRaiderRepository;

    private final UserStarRaiderRepository userStarRaiderRepository;

    private final RaiderCommentRepository raiderCommentRepository;

    private final RaiderKindRepository raiderKindRepository;

    private final UserRaiderRepository userRaiderRepository;

    private final JdbcTemplate jdbcTemplate;

    public RaiderController(RaiderDetailRepository raiderDetailRepository,
                            RaiderEntityRepository raiderEntityRepository,
                            UserSaveRaiderRepository userSaveRaiderRepository,
                            UserStarRaiderRepository userStarRaiderRepository,
                            RaiderCommentRepository raiderCommentRepository,
                            RaiderKindRepository raiderKindRepository,
                            UserRaiderRepository userRaiderRepository,
                            JdbcTemplate jdbcTemplate) {
        this.raiderDetailRepository = raiderDetailRepository;
        this.raiderEntityRepository = raiderEntityRepository;
        this.userSaveRaiderRepository = userSaveRaiderRepository;
        this.userStarRaiderRepository = userStarRaiderRepository;
        this.raiderCommentRepository = raiderCommentRepository;
        this.raiderKindRepository = raiderKindRepository;
        this.userRaiderRepository = userRaiderRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping(path = "/findRaiderByKeyWord")
    public String findRaiderByKeyWord(Model model,
                                      String keyWord) {
        if (keyWord == null || keyWord.trim().length() == 0) {
            return "error";
        }

        try {
            List<RaiderEntity> raiderEntities =
                    raiderEntityRepository.getRaiderEntityByKeyWord(keyWord);

            model.addAttribute("raiders", raiderEntities);
            return "raider";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/getRaiderByNav")
    public String getRaiderByNav(Model model,
                                 String keyWord,
                                 short placeholder) {
        if (keyWord == null || keyWord.trim().length() == 0) {
            return "error";
        }

        try {
            List<RaiderEntity> raiderEntities = new ArrayList<>();
            if (placeholder <=2 ) {
                raiderEntities =
                        raiderEntityRepository.getRaiderEntityByKeyWord(keyWord);
            }

            if (placeholder == 3) {
                raiderEntities =
                        raiderEntityRepository.getRaiderEntitiesOrderByVisitNum();
            } else if (placeholder == 4) {
                raiderEntities =
                        raiderEntityRepository.getRaiderEntitiesOrderByStar();
            }

            model.addAttribute("raiders", raiderEntities);
            model.addAttribute("placeholder", placeholder);
            return "raiderNav";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/raiderDetail")
    public String getRaiderDetail(Model model,
                                  String raiderId,
                                  @CookieValue(value = "userId") String userId) {
        if (raiderId == null || raiderId.trim().length() == 0) {
            return "error";
        }

        if (userId == null || userId.trim().length() == 0) {
            return "error";
        }

        try {
            RaiderEntity raiderEntity =
                    raiderEntityRepository.getRaiderEntityByRaiderId(raiderId);
            List<RaiderDetail> raiderDetails =
                    raiderDetailRepository.getRaiderDetailsByRaiderIdOrderByRaiderStep(raiderId);
            UserSaveRaiderEntity userSaveRaiderEntity =
                    userSaveRaiderRepository.getUserSaveRaiderEntityByRaiderIdAndUserId(raiderId, userId);
            UserStarRaiderEntity userStarRaiderEntity =
                    userStarRaiderRepository.getUserStarRaiderEntityByUserIdAndRaiderId(userId, raiderId);
            List<RaiderCommentEntity> raiderCommentEntityList =
                    raiderCommentRepository.getRaiderCommentEntitiesByRaiderIdOrderByCommentDate(raiderId);
            raiderEntityRepository.updateVisitNum(raiderId);

            model.addAttribute("raiderEntity", raiderEntity);
            model.addAttribute("raiderDetails", raiderDetails);
            model.addAttribute("raiderComments", raiderCommentEntityList);
            model.addAttribute("isSave", userSaveRaiderEntity != null);
            model.addAttribute("isStar", userStarRaiderEntity != null);

            return "raiderDetail";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/saveRaider")
    public void saveRaider(HttpServletResponse response,
                           String raiderId,
                           @CookieValue(value = "userId") String userId) throws IOException {
        try (PrintWriter printWriter = response.getWriter()){
            if (raiderId == null || raiderId.trim().length() == 0) {
                printWriter.write("0");
                return;
            }
            if (userId == null || userId.trim().length() == 0) {
                printWriter.write("0");
                return;
            }

            SimpleDateFormat simpleDateFormat =
                    new SimpleDateFormat("yyyy-MM-dd");
            Date date = new Date();

            UserSaveRaiderEntity userSaveRaiderEntity =
                    new UserSaveRaiderEntity();

            userSaveRaiderEntity.setRaiderId(raiderId);
            userSaveRaiderEntity.setUserId(userId);
            userSaveRaiderEntity.setSaveDate(java.sql.Date.valueOf(simpleDateFormat.format(date)));

            userSaveRaiderRepository.save(userSaveRaiderEntity);

            printWriter.write("1");
        } catch (Exception e) {
            response.getWriter().write("0");
        }
    }

    @GetMapping(path = "/starRaider")
    public void starRaider(HttpServletResponse response,
                           String raiderId,
                           Integer star,
                           @CookieValue(value = "userId") String userId) throws IOException {
        try (PrintWriter printWriter = response.getWriter()) {
            if (raiderId == null || raiderId.trim().length() == 0) {
                printWriter.write("0");
                return;
            }
            if (userId == null || userId.trim().length() == 0) {
                printWriter.write("0");
                return;
            }

            SimpleDateFormat simpleDateFormat =
                    new SimpleDateFormat("yyyy-MM-dd");
            Date date = new Date();

            UserStarRaiderEntity userStarRaiderEntity =
                    new UserStarRaiderEntity();

            userStarRaiderEntity.setRaiderId(raiderId);
            userStarRaiderEntity.setUserId(userId);
            userStarRaiderEntity.setStarDate(java.sql.Date.valueOf(simpleDateFormat.format(date)));

            RaiderStarImpl raiderStar = new RaiderStarImpl(jdbcTemplate);

            raiderStar.saveRaiderStarEntity(userStarRaiderEntity);

            RaiderEntity raiderEntity =
                    raiderEntityRepository.getRaiderEntityByRaiderId(raiderId);

            printWriter.write(String.valueOf(raiderEntity.getStars()));
        } catch (Exception e) {
            response.getWriter().write("0");
        }
    }

    @PostMapping(path = "/sendRaiderComment")
    public void sendRaiderComment(HttpServletResponse response,
                                  String raiderId,
                                  String raiderComment,
                                  @CookieValue(value = "userId") String userId) throws IOException {
        try (PrintWriter printWriter = response.getWriter()){
            if (raiderId == null || raiderId.trim().length() == 0) {
                printWriter.write("0");
                return;
            }

            if (raiderComment == null || raiderComment.trim().length() == 0) {
                printWriter.write("0");
                return;
            }

            if (userId == null || userId.trim().length() == 0) {
                printWriter.write("0");
                return;
            }

            SimpleDateFormat simpleDateFormat = new SimpleDateFormat("yyyy-MM-dd");
            RaiderCommentImpl raiderComment1 = new RaiderCommentImpl(jdbcTemplate);

            RaiderCommentEntity raiderCommentEntity = new RaiderCommentEntity();
            raiderCommentEntity.setUserId(userId);
            raiderCommentEntity.setRaiderId(raiderId);
            raiderCommentEntity.setCommentContent(raiderComment);
            raiderCommentEntity.setCommentDate(java.sql.Date.
                    valueOf(simpleDateFormat.format(new Date())));

            raiderComment1.insertRaiderCommentEntity(raiderCommentEntity);

            printWriter.write("1");
        } catch (Exception e) {
            response.getWriter().write("0");
        }
    }

    @GetMapping(path = "/writeRaider")
    public String writeRaider(Model model,
                              @CookieValue(value = "userId") String userId) {
        if (userId == null || userId.trim().length() == 0) {
            return "error";
        }

        try {
            model.addAttribute("userId", userId);
            return "writeRaider";
        } catch (Exception e) {
            return "error";
        }
    }

    @PostMapping(path = "/saveRaiderDetail")
    public void saveRaiderDetail(HttpServletResponse response,
                                 @NonNull String raiderKindJson,
                                 @NonNull String raiderEntityJson,
                                 @NonNull String dataJson,
                                 @CookieValue(value = "userId") String userId) throws IOException {
        try (PrintWriter printWriter = response.getWriter()){
            SqlDateTypeAdapter sqlAdapter = new SqlDateTypeAdapter();
            Gson gson = new GsonBuilder()
                    .registerTypeAdapter(java.util.Date.class, sqlAdapter )
                    .setDateFormat("yyyy-MM-dd")
                    .create();

            List<RaiderDetail> raiderDetails =
                    gson.fromJson(dataJson, new TypeToken<List<RaiderDetail>>(){}.getType());

            RaiderEntity raiderEntity = gson.fromJson(raiderEntityJson, RaiderEntity.class);

            UserRaiderEntity userRaiderEntity = new UserRaiderEntity();
            userRaiderEntity.setUserId(userId);
            userRaiderEntity.setRaiderId(raiderEntity.getRaiderId());

            userRaiderRepository.save(userRaiderEntity);

            RaiderKindEntity raiderKindEntity =
                    gson.fromJson(raiderKindJson, RaiderKindEntity.class);

            raiderEntityRepository.save(raiderEntity);

            raiderKindRepository.save(raiderKindEntity);

            raiderDetailRepository.saveAll(raiderDetails);

            printWriter.write("1");
        } catch (Exception e) {
            e.printStackTrace();
            response.getWriter().write("0");
        }
    }
}
